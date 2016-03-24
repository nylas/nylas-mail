import _ from 'underscore';
import DatabaseStore from '../stores/database-store';
import QueryRange from './query-range';
import MutableQueryResultSet from './mutable-query-result-set';

export default class QuerySubscription {
  constructor(query, options = {}) {
    this._query = query;
    this._options = options;

    this._set = null;
    this._callbacks = [];
    this._lastResult = null;
    this._updateInFlight = false;
    this._queuedChangeRecords = [];
    this._queryVersion = 1;

    if (this._query) {
      if (this._query._count) {
        throw new Error("QuerySubscriptionPool::add - You cannot listen to count queries.")
      }

      this._query.finalize();

      if (this._options.initialModels) {
        this._set = new MutableQueryResultSet();
        this._set.addModelsInRange(this._options.initialModels, new QueryRange({
          limit: this._options.initialModels.length,
          offset: 0,
        }));
        this._createResultAndTrigger();
      } else {
        this.update();
      }
    }
  }

  query = () => {
    return this._query;
  }

  addCallback = (callback) => {
    if (!(callback instanceof Function)) {
      throw new Error("QuerySubscription:addCallback - expects a function, received #{callback}");
    }
    this._callbacks.push(callback);

    if (this._lastResult) {
      process.nextTick(() => {
        if (!this._lastResult) { return; }
        callback(this._lastResult);
      });
    }
  }

  hasCallback = (callback) => {
    return (this._callbacks.indexOf(callback) !== -1);
  }

  removeCallback = (callback) => {
    if (!(callback instanceof Function)) {
      throw new Error("QuerySubscription:removeCallback - expects a function, received #{callback}")
    }
    this._callbacks = _.without(this._callbacks, callback);
  }

  callbackCount = () => {
    return this._callbacks.length;
  }

  applyChangeRecord = (record) => {
    if (!this._query || record.objectClass !== this._query.objectClass()) {
      return;
    }
    if (record.objects.length === 0) {
      return;
    }

    this._queuedChangeRecords.push(record);
    if (!this._updateInFlight) {
      this._processChangeRecords();
    }
  }

  cancelPendingUpdate = () => {
    this._queryVersion += 1;
    this._updateInFlight = false;
  }

  // Scan through change records and apply them to the last result set.
  // - Returns true if changes did / will result in new result set being created.
  // - Returns false if no changes were made.

  _processChangeRecords = () => {
    if (this._queuedChangeRecords.length === 0) {
      return false;
    }
    if (!this._set) {
      this.update();
      return true;
    }

    let knownImpacts = 0;
    let unknownImpacts = 0;
    let mustRefetchAllIds = false;

    this._queuedChangeRecords.forEach((record) => {
      if (record.type === 'unpersist') {
        for (const item of record.objects) {
          const offset = this._set.offsetOfId(item.clientId)
          if (offset !== -1) {
            this._set.removeModelAtOffset(item, offset);
            unknownImpacts += 1;
          }
        }
      } else if (record.type === 'persist') {
        for (const item of record.objects) {
          const offset = this._set.offsetOfId(item.clientId);
          const itemIsInSet = offset !== -1;
          const itemShouldBeInSet = item.matches(this._query.matchers());

          if (itemIsInSet && !itemShouldBeInSet) {
            this._set.removeModelAtOffset(item, offset)
            unknownImpacts += 1
          } else if (itemShouldBeInSet && !itemIsInSet) {
            this._set.replaceModel(item)
            mustRefetchAllIds = true
            unknownImpacts += 1;
          } else if (itemIsInSet) {
            const oldItem = this._set.modelWithId(item.clientId);
            this._set.replaceModel(item);

            if (this._itemSortOrderHasChanged(oldItem, item)) {
              mustRefetchAllIds = true
              unknownImpacts += 1
            } else {
              knownImpacts += 1
            }
          }
        }
        // If we're not at the top of the result set, we can't be sure whether an
        // item previously matched the set and doesn't anymore, impacting the items
        // in the query range. We need to refetch IDs to be sure our set === correct.
        if ((this._query.range().offset > 0) && (unknownImpacts + knownImpacts) < record.objects.length) {
          mustRefetchAllIds = true
          unknownImpacts += 1
        }
      }
    });

    this._queuedChangeRecords = [];

    if (unknownImpacts > 0) {
      if (mustRefetchAllIds) {
        this._set = null;
      }
      this.update();
      return true;
    }
    if (knownImpacts > 0) {
      this._createResultAndTrigger();
      return false;
    }
    return false;
  }

  _itemSortOrderHasChanged(old, updated) {
    for (const descriptor of this._query.orderSortDescriptors()) {
      const oldSortValue = old[descriptor.attr.modelKey];
      const updatedSortValue = updated[descriptor.attr.modelKey];

      // http://stackoverflow.com/questions/4587060/determining-date-equality-in-javascript
      if (!(oldSortValue >= updatedSortValue && oldSortValue <= updatedSortValue)) {
        return true;
      }
    }
    return false;
  }

  update() {
    this._updateInFlight = true;

    const version = this._queryVersion;
    const desiredRange = this._query.range();
    const currentRange = this._set ? this._set.range() : null;
    const areNotInfinite = currentRange && !currentRange.isInfinite() && !desiredRange.isInfinite();
    const previousResultIsEmpty = !this._set || this._set.modelCacheCount() === 0;
    const missingRange = this._getMissingRange(desiredRange, currentRange);
    const fetchEntireModels = areNotInfinite ? true : previousResultIsEmpty;

    this._fetchMissingRange(missingRange, {version, fetchEntireModels});
  }

  _getMissingRange = (desiredRange, currentRange) => {
    if (currentRange && !currentRange.isInfinite() && !desiredRange.isInfinite()) {
      const ranges = QueryRange.rangesBySubtracting(desiredRange, currentRange);
      return (ranges.length === 1) ? ranges[0] : desiredRange;
    }
    return desiredRange;
  }

  _getQueryForRange = (range, fetchEntireModels) => {
    let rangeQuery = null;
    if (!range.isInfinite()) {
      rangeQuery = rangeQuery || this._query.clone();
      rangeQuery.offset(range.offset).limit(range.limit);
    }
    if (!fetchEntireModels) {
      rangeQuery = rangeQuery || this._query.clone();
      rangeQuery.idsOnly();
    }
    rangeQuery = rangeQuery || this._query;
    return rangeQuery;
  }

  _fetchMissingRange(missingRange, {version, fetchEntireModels}) {
    const missingRangeQuery = this._getQueryForRange(missingRange, fetchEntireModels);

    DatabaseStore.run(missingRangeQuery, {format: false}).then((results) => {
      if (this._queryVersion !== version) {
        return;
      }

      if (this._set && !this._set.range().isContiguousWith(missingRange)) {
        this._set = null;
      }
      this._set = this._set || new MutableQueryResultSet();

      // Create result and trigger if either of the following:
      // A) no changes have come in during querying the missing range,
      // B) applying those changes has no effect on the result set, and this one is
      //    still good.
      if ((this._queuedChangeRecords.length === 0) || (this._processChangeRecords() === false)) {
        if (fetchEntireModels) {
          this._set.addModelsInRange(results, missingRange);
        } else {
          this._set.addIdsInRange(results, missingRange);
        }

        this._set.clipToRange(this._query.range());

        const missingIds = this._set.ids().filter(id => !this._set.modelWithId(id));
        if (missingIds.length > 0) {
          DatabaseStore.findAll(this._query._klass, {id: missingIds}).then((models) => {
            if (this._queryVersion !== version) {
              return;
            }
            for (const m of models) {
              this._set.replaceModel(m);
            }
            this._updateInFlight = false;
            this._createResultAndTrigger();
          });
        } else {
          this._updateInFlight = false;
          this._createResultAndTrigger();
        }
      }
    });
  }

  _createResultAndTrigger = () => {
    const allCompleteModels = this._set.isComplete()
    const allUniqueIds = _.uniq(this._set.ids()).length === this._set.ids().length

    if (!allUniqueIds) {
      throw new Error("QuerySubscription: Applied all changes and result set contains duplicate IDs.");
    }

    if (!allCompleteModels) {
      throw new Error("QuerySubscription: Applied all changes and result set === missing models.");
    }

    if (this._options.asResultSet) {
      this._set.setQuery(this._query);
      this._lastResult = this._set.immutableClone();
    } else {
      this._lastResult = this._query.formatResult(this._set.models());
    }

    this._callbacks.forEach((callback) => callback(this._lastResult));
  }
}
