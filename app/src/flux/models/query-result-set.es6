import QueryRange from './query-range';

/*
Public: Instances of QueryResultSet hold a set of models retrieved
from the database at a given offset.

Complete vs Incomplete:

QueryResultSet keeps an array of item ids and a lookup table of models.
The lookup table may be incomplete if the QuerySubscription isn't finished
preparing results. You can use `isComplete` to determine whether the set
has every model.

Offset vs Index:

To avoid confusion, "index" refers to an item's position in an
array, and "offset" refers to it's position in the query result set. For example,
an item might be at index 20 in the _ids array, but at offset 120 in the result.
*/
export default class QueryResultSet {
  static setByApplyingModels(set, models) {
    if (models instanceof Array) {
      throw new Error('setByApplyingModels: A hash of models is required.');
    }
    const out = set.clone();
    out._modelsHash = models;
    out._idToIndexHash = null;
    return out;
  }

  constructor(other = {}) {
    this._offset = other._offset !== undefined ? other._offset : null;
    this._query = other._query !== undefined ? other._query : null;
    this._idToIndexHash = other._idToIndexHash !== undefined ? other._idToIndexHash : null;
    // Clone, since the others may be frozen
    this._modelsHash = Object.assign({}, other._modelsHash || {});
    this._ids = [].concat(other._ids || []);
  }

  clone() {
    return new this.constructor({
      _ids: [].concat(this._ids),
      _modelsHash: Object.assign({}, this._modelsHash),
      _idToIndexHash: Object.assign({}, this._idToIndexHash),
      _query: this._query,
      _offset: this._offset,
    });
  }

  isComplete() {
    return this._ids.every(id => this._modelsHash[id]);
  }

  range() {
    return new QueryRange({ offset: this._offset, limit: this._ids.length });
  }

  query() {
    return this._query;
  }

  count() {
    return this._ids.length;
  }

  empty() {
    return this.count() === 0;
  }

  ids() {
    return this._ids;
  }

  idAtOffset(offset) {
    return this._ids[offset - this._offset];
  }

  models() {
    return this._ids.map(id => this._modelsHash[id]);
  }

  modelCacheCount() {
    return Object.keys(this._modelsHash).length;
  }

  modelAtOffset(offset) {
    if (!Number.isInteger(offset)) {
      throw new Error(
        'QueryResultSet.modelAtOffset() takes a numeric index. Maybe you meant modelWithId()?'
      );
    }
    return this._modelsHash[this._ids[offset - this._offset]];
  }

  modelWithId(id) {
    return this._modelsHash[id];
  }

  buildIdToIndexHash() {
    this._idToIndexHash = {};
    this._ids.forEach((id, idx) => {
      this._idToIndexHash[id] = idx;
    });
  }

  offsetOfId(id) {
    if (this._idToIndexHash === null) {
      this.buildIdToIndexHash();
    }

    if (this._idToIndexHash[id] === undefined) {
      return -1;
    }
    return this._idToIndexHash[id] + this._offset;
  }
}
