import { DatabaseStore } from 'nylas-exports';

const INDEXING_PAGE_SIZE = 1000;
const INDEXING_PAGE_DELAY = 1000;

export default class ModelSearchIndexer {
  constructor() {
    this.unsubscribers = []
    this.indexer = null;
  }

  get MaxIndexSize() {
    throw new Error("Override me and return a number")
  }

  get ConfigKey() {
    throw new Error("Override me and return a string config key")
  }

  get IndexVersion() {
    throw new Error("Override me and return an IndexVersion")
  }

  get ModelClass() {
    throw new Error("Override me and return a class constructor")
  }

  getIndexDataForModel() {
    throw new Error("Override me and return a hash with a `content` array")
  }

  activate(indexer) {
    this.indexer = indexer;
    this.indexer.registerSearchableModel({
      modelClass: this.ModelClass,
      indexSize: this.MaxIndexSize,
      indexCallback: (model) => this._indexModel(model),
      unindexCallback: (model) => this._unindexModel(model),
    });

    this._initializeIndex();
    this.unsubscribers = [
      // TODO listen for changes in AccountStore
      DatabaseStore.listen(this._onDataChanged),
      () => indexer.unregisterSearchableModel(this.ModelClass),
    ];
  }

  deactivate() {
    this.unsubscribers.forEach(unsub => unsub())
    this.indexer = null;
  }

  _initializeIndex() {
    if (NylasEnv.config.get(this.ConfigKey) !== this.IndexVersion) {
      return DatabaseStore.dropSearchIndex(this.ModelClass)
      .then(() => DatabaseStore.createSearchIndex(this.ModelClass))
      .then(() => this._buildIndex())
    }
    return Promise.resolve()
  }

  _buildIndex(offset = 0) {
    const {ModelClass, IndexVersion, ConfigKey} = this
    return DatabaseStore.findAll(ModelClass)
    .limit(INDEXING_PAGE_SIZE)
    .offset(offset)
    .background()
    .then((models) => {
      if (models.length === 0) {
        NylasEnv.config.set(ConfigKey, IndexVersion)
        return;
      }
      Promise.each(models, (model) => {
        return DatabaseStore.indexModel(model, this.getIndexDataForModel(model))
      })
      .then(() => {
        setTimeout(() => {
          this._buildIndex(offset + models.length);
        }, INDEXING_PAGE_DELAY);
      });
    });
  }

  _indexModel(model) {
    DatabaseStore.indexModel(model, this.getIndexDataForModel(model))
  }

  _unindexModel(model) {
    DatabaseStore.unindexModel(model)
  }

  /**
   * When a model gets updated we will update the search index with the
   * data from that model if the account it belongs to is not being
   * currently synced.
   */
  _onDataChanged = (change) => {
    if (change.objectClass !== this.ModelClass.name) {
      return;
    }

    change.objects.forEach((model) => {
      if (change.type === 'persist') {
        this.indexer.notifyHasIndexingToDo();
      } else {
        this._unindexModel(model);
      }
    });
  }
}
