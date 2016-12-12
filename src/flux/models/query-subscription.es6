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
        throw new Error("QuerySubscription::constructor - You cannot listen to count queries.")
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
      throw new Error(`QuerySubscription:addCallback - expects a function, received ${callback}`);
    }
    this._callbacks.push(callback);

    if (this._lastResult) {
      setTimeout(() => {
        if (!this._lastResult) { return; }
        callback(this._lastResult);
      }, 0);
    }
  }

  hasCallback = (callback) => {
    return (this._callbacks.indexOf(callback) !== -1);
  }

  removeCallback(callback) {
    if (!(callback instanceof Function)) {
      throw new Error(`QuerySubscription:removeCallback - expects a function, received ${callback}`)
    }
    this._callbacks = _.without(this._callbacks, callback);
    if (this.callbackCount() === 0) {
      this.onLastCallbackRemoved()
    }
  }

  onLastCallbackRemoved() {

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
  _processChangeRecords = () => {
    if (this._queuedChangeRecords.length === 0) {
      return;
    }
    if (!this._set) {
      this.update();
      return;
    }

    let knownImpacts = 0;
    let unknownImpacts = 0;

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
            this._set.updateModel(item)
            unknownImpacts += 1;
          } else if (itemIsInSet) {
            const oldItem = this._set.modelWithId(item.clientId);
            this._set.updateModel(item);

            if (this._itemSortOrderHasChanged(oldItem, item)) {
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
          unknownImpacts += 1
        }
      }
    });

    this._queuedChangeRecords = [];

    if (unknownImpacts > 0) {
      this.update({mustRefetchEntireRange: true});
    } else if (knownImpacts > 0) {
      this._createResultAndTrigger();
    }
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

  update({mustRefetchEntireRange} = {}) {
    this._updateInFlight = true;

    const desiredRange = this._query.range();
    const currentRange = this._set ? this._set.range() : null;
    const hasNonInfiniteRange = currentRange && !currentRange.isInfinite() && !desiredRange.isInfinite();

    // If we have a limited range, and changes don't require that we refetch
    // the entire range, just fetch the missing items. This is the path typically
    // used while scrolling.
    if (hasNonInfiniteRange && !mustRefetchEntireRange) {
      const missingRange = this._getMissingRange(desiredRange, currentRange);
      this._fetchRange(missingRange, {
        version: this._queryVersion,
        fetchEntireModels: true,
      });
    } else {
      const haveNoModels = !this._set || this._set.modelCacheCount() === 0;
      this._fetchRange(desiredRange, {
        version: this._queryVersion,
        fetchEntireModels: haveNoModels,
      });
    }
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

  _fetchRange(range, {version, fetchEntireModels}) {
    const rangeQuery = this._getQueryForRange(range, fetchEntireModels);

    DatabaseStore.run(rangeQuery, {format: false}).then((results) => {
      if (this._queryVersion !== version) {
        return;
      }

      if (this._set && !this._set.range().isContiguousWith(range)) {
        this._set = null;
      }
      this._set = this._set || new MutableQueryResultSet();

      if (fetchEntireModels) {
        this._set.addModelsInRange(results, range);
      } else {
        this._set.addIdsInRange(results, range);
      }

      this._set.clipToRange(this._query.range());

      this._fetchMissingModels().then((models) => {
        if (this._queryVersion !== version) {
          return;
        }
        for (const m of models) {
          this._set.updateModel(m);
        }
        this._createResultAndTrigger();
      });
    });
  }

  _fetchMissingModels() {
    const missingIds = this._set.ids().filter(id => !this._set.modelWithId(id));
    if (missingIds.length === 0) {
      return Promise.resolve([]);
    }
    return DatabaseStore.findAll(this._query._klass, {id: missingIds});
  }

  _createResultAndTrigger = () => {
    const allCompleteModels = this._set.isComplete()
    const allUniqueIds = _.uniq(this._set.ids()).length === this._set.ids().length

    let error = null;
    if (!allCompleteModels) {
      error = new Error("QuerySubscription: Applied all changes and result set is missing models.");
    }
    if (!allUniqueIds) {
      error = new Error("QuerySubscription: Applied all changes and result set contains duplicate IDs.");
    }

    if (error) {
      NylasEnv.reportError(error);
      this._set = null;
      this.update();
      return;
    }

    if (this._options.emitResultSet) {
      this._set.setQuery(this._query);
      this._lastResult = this._set.immutableClone();
    } else {
      this._lastResult = this._query.formatResult(this._set.models());
    }

    this._callbacks.forEach((callback) => callback(this._lastResult));

    // process any additional change records that have arrived
    if (this._updateInFlight) {
      this._updateInFlight = false;
      this._processChangeRecords();
    }
  }
}
