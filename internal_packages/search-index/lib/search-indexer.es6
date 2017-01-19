import _ from 'underscore';
import {
  DatabaseStore,
} from 'nylas-exports'

const CHUNK_SIZE = 10;
const FRACTION_CPU_AVAILABLE = 0.05;
const MIN_TIMEOUT = 1000;
const MAX_TIMEOUT = 5 * 60 * 1000; // 5 minutes

export default class SearchIndexer {
  constructor() {
    this._searchableModels = {};
    this._hasIndexingToDo = false;
    this._lastTimeStart = null;
    this._lastTimeStop = null;
  }

  registerSearchableModel({modelClass, indexSize, indexCallback, unindexCallback}) {
    this._searchableModels[modelClass.name] = {modelClass, indexSize, indexCallback, unindexCallback};
  }

  unregisterSearchableModel(modelClass) {
    delete this._searchableModels[modelClass.name];
  }

  async _getIndexCutoff(modelClass, indexSize) {
    const query = DatabaseStore.findAll(modelClass)
      .order(modelClass.naturalSortOrder())
      .offset(indexSize)
      .limit(1)
    // console.info('SearchIndexer: _getIndexCutoff query', query.sql());
    const models = await query;
    return models[0];
  }

  _getNewUnindexed(modelClass, indexSize, cutoff) {
    const whereConds = [modelClass.attributes.isSearchIndexed.equal(false)];
    if (cutoff) {
      whereConds.push(modelClass.sortOrderAttribute().greaterThan(cutoff[modelClass.sortOrderAttribute().modelKey]));
    }
    const query = DatabaseStore.findAll(modelClass)
      .where(whereConds)
      .limit(CHUNK_SIZE)
      .order(modelClass.naturalSortOrder())
    // console.info('SearchIndexer: _getNewUnindexed query', query.sql());
    return query;
  }

  _getOldIndexed(modelClass, cutoff) {
    // If there's no cutoff then that means we haven't reached the max index size yet.
    if (!cutoff) {
      return Promise.resolve([]);
    }
    const whereConds = [
      modelClass.attributes.isSearchIndexed.equal(true),
      modelClass.sortOrderAttribute().lessThanOrEqualTo(cutoff[modelClass.sortOrderAttribute().modelKey]),
    ];
    const query = DatabaseStore.findAll(modelClass)
      .where(whereConds)
      .limit(CHUNK_SIZE)
      .order(modelClass.naturalSortOrder())
    // console.info('SearchIndexer: _getOldIndexed query', query.sql());
    return query;
  }

  async _getIndexDiff() {
    const results = await Promise.all(Object.keys(this._searchableModels).map(async (modelName) => {
      const {modelClass, indexSize} = this._searchableModels[modelName];
      const cutoff = await this._getIndexCutoff(modelClass, indexSize);
      const [toIndex, toUnindex] = await Promise.all([
        this._getNewUnindexed(modelClass, indexSize, cutoff),
        this._getOldIndexed(modelClass, cutoff),
      ]);
      // console.info('SearchIndexer: ', modelClass.name);
      // console.info('SearchIndexer: _getIndexCutoff cutoff', cutoff);
      // console.info('SearchIndexer: _getIndexDiff toIndex', toIndex.map((model) => [model.isSearchIndexed, model.subject]));
      // console.info('SearchIndexer: _getIndexDiff toUnindex', toUnindex.map((model) => [model.isSearchIndexed, model.subject]));
      return [toIndex, toUnindex];
    }));
    const [toIndex, toUnindex] = _.unzip(results).map((l) => _.flatten(l))
    return {toIndex, toUnindex};
  }

  _indexItems(items) {
    return Promise.all([items.map((item) => this._searchableModels[item.constructor.name].indexCallback(item))]);
  }

  _unindexItems(items) {
    return Promise.all([items.map((item) => this._searchableModels[item.constructor.name].unindexCallback(item))]);
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

  async run() {
    if (!this._hasIndexingToDo) {
      return;
    }

    const start = new Date();
    const {toIndex, toUnindex} = await this._getIndexDiff();
    if (toIndex.length !== 0 || toUnindex.length !== 0) {
      await Promise.all([
        this._indexItems(toIndex),
        this._unindexItems(toUnindex),
      ]);
      this._lastTimeStart = start;
      this._lastTimeStop = new Date();
      // console.info(`SearchIndexer: ${toIndex.length} items indexed, ${toUnindex.length} items unindexed, took ${this._lastTimeStop.getTime() - this._lastTimeStart.getTime()} ms`);
      this._scheduleRun();
    } else {
      // const stop = new Date();
      // console.info(`SearchIndexer: No changes to index, took ${stop.getTime() - start.getTime()} ms`);
      this._hasIndexingToDo = false;
    }
  }
}
