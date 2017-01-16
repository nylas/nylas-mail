import {
  DatabaseStore,
} from 'nylas-exports'

const FRACTION_CPU_AVAILABLE = 0.05;
const MAX_TIME_SLICE_MILLIS = 100;
const CHUNK_SIZE = 10;
const MIN_TIMEOUT = 100;
const MAX_TIMEOUT = 5 * 60 * 1000; // 5 minutes

export default class SearchIndexer {
  constructor() {
    this._searchableModels = {};
    this._hasIndexingToDo = false;
    this._lastTimeStart = null;
    this._lastTimeStop = null;
  }

  registerSearchableModel(klass, indexCallback) {
    this._searchableModels[klass.name] = {klass, cb: indexCallback};
  }

  unregisterSearchableModel(klass) {
    delete this._searchableModels[klass.name];
  }

  async _getNewItemsToIndex() {
    const results = await Promise.all(Object.keys(this._searchableModels).map((modelName) => {
      const modelClass = this._searchableModels[modelName].klass;
      const query = DatabaseStore.findAll(modelClass)
                    .where(modelClass.attributes.isSearchIndexed.equal(false))
                    .order(modelClass.attributes.id.ascending())
                    .limit(CHUNK_SIZE);
      // console.info(query.sql());
      return query;
    }));
    return results.reduce((acc, curr) => acc.concat(curr), []);
  }

  _indexItems(items) {
    for (const item of items) {
      this._searchableModels[item.constructor.name].cb(item);
    }
  }

  notifyHasIndexingToDo() {
    if (this._hasIndexingToDo) {
      return;
    }
    this._hasIndexingToDo = true;
    this._scheduleRun();
  }

  _computeNextTimeout() {
    if (!this._lastTimeStop || !this._lastTimeStart) {
      return MIN_TIMEOUT;
    }
    const spanMillis = this._lastTimeStop.getTime() - this._lastTimeStart.getTime();
    const multiplier = 1.0 / FRACTION_CPU_AVAILABLE;
    return Math.min(Math.max(spanMillis * multiplier, MIN_TIMEOUT), MAX_TIMEOUT);
  }

  _scheduleRun() {
    // console.info(`SearchIndexer: setting timeout for ${this._computeNextTimeout()} ms`);
    setTimeout(() => this.run(), this._computeNextTimeout());
  }

  run() {
    if (!this._hasIndexingToDo) {
      return;
    }

    const start = new Date();
    let current = new Date();
    let firstIter = true;
    let numItemsIndexed = 0;

    const indexNextChunk = (unindexedItems) => {
      if (firstIter) {
        this._lastTimeStart = start;
        firstIter = false;
      }

      if (unindexedItems.length === 0) {
        this._hasIndexingToDo = false;
        this._lastTimeStop = new Date();
        // console.info(`Finished indexing ${numItemsIndexed} items, took ${current.getTime() - start.getTime()} ms`);
        return;
      }

      this._indexItems(unindexedItems);
      numItemsIndexed += unindexedItems.length;
      current = new Date();

      if (current.getTime() - start.getTime() <= MAX_TIME_SLICE_MILLIS) {
        this._getNewItemsToIndex().then(indexNextChunk);
        return;
      }

      this._lastTimeStop = new Date();
      // console.info(`SearchIndexer: Finished indexing ${numItemsIndexed} items, took ${current.getTime() - start.getTime()} ms`);
      this._scheduleRun();
    };
    this._getNewItemsToIndex().then(indexNextChunk);
  }
}
