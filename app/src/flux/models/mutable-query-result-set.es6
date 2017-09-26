import QueryResultSet from './query-result-set';
import AttributeJoinedData from '../attributes/attribute-joined-data';

// TODO: Make mutator methods QueryResultSet.join(), QueryResultSet.clip...
export default class MutableQueryResultSet extends QueryResultSet {
  immutableClone() {
    const set = new QueryResultSet({
      _ids: [].concat(this._ids),
      _modelsHash: Object.assign({}, this._modelsHash),
      _query: this._query,
      _offset: this._offset,
    });
    Object.freeze(set._ids);
    Object.freeze(set._modelsHash);
    return set;
  }

  clipToRange(range) {
    if (range.isInfinite()) {
      return;
    }
    if (range.offset > this._offset) {
      this._ids = this._ids.slice(range.offset - this._offset);
      this._offset = range.offset;
    }

    const rangeEnd = range.offset + range.limit;
    const selfEnd = this._offset + this._ids.length;
    if (rangeEnd < selfEnd) {
      this._ids.length = Math.max(0, rangeEnd - this._offset);
    }

    const models = this.models();
    this._modelsHash = {};
    this._idToIndexHash = null;
    models.forEach(m => this.updateModel(m));
  }

  addModelsInRange(rangeModels, range) {
    this.addIdsInRange(rangeModels.map(m => m.id), range);
    rangeModels.forEach(m => this.updateModel(m));
  }

  addIdsInRange(rangeIds, range) {
    if (this._offset === null || range.isInfinite()) {
      this._ids = rangeIds;
      this._idToIndexHash = null;
      this._offset = range.offset;
    } else {
      const currentEnd = this._offset + this._ids.length;
      const rangeIdsEnd = range.offset + rangeIds.length;

      if (rangeIdsEnd < this._offset) {
        throw new Error(
          `addIdsInRange: You can only add adjacent values (${rangeIdsEnd} < ${this._offset})`
        );
      }
      if (range.offset > currentEnd) {
        throw new Error(
          `addIdsInRange: You can only add adjacent values (${range.offset} > ${currentEnd})`
        );
      }

      let existingBefore = [];
      if (range.offset > this._offset) {
        existingBefore = this._ids.slice(0, range.offset - this._offset);
      }

      let existingAfter = [];
      if (rangeIds.length === range.limit && currentEnd > rangeIdsEnd) {
        existingAfter = this._ids.slice(rangeIdsEnd - this._offset);
      }

      this._ids = [].concat(existingBefore, rangeIds, existingAfter);
      this._idToIndexHash = null;
      this._offset = Math.min(this._offset, range.offset);
    }
  }

  updateModel(item) {
    if (!item) {
      return;
    }

    // Sometimes the new copy of `item` doesn't contain the joined data present
    // in the old one, since it's not provided by default and may not have changed.
    // Make sure we never drop joined data by pulling it over.
    const existing = this._modelsHash[item.id];
    if (existing) {
      const attrs = existing.constructor.attributes;
      for (const key of Object.keys(attrs)) {
        const attr = attrs[key];
        if (attr instanceof AttributeJoinedData && item[attr.modelKey] === undefined) {
          item[attr.modelKey] = existing[attr.modelKey];
        }
      }
    }

    this._modelsHash[item.id] = item;
  }

  removeModelAtOffset(item, offset) {
    const idx = offset - this._offset;
    delete this._modelsHash[item.id];
    this._ids.splice(idx, 1);
    this._idToIndexHash = null;
  }

  setQuery(query) {
    this._query = query.clone();
    this._query.finalize();
  }
}
