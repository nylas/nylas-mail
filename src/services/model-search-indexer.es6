import { DatabaseStore } from 'nylas-exports';

const INDEXING_PAGE_SIZE = 1000;
const INDEXING_PAGE_DELAY = 1000;

export default class ModelSearchIndexer {
  constructor() {
    this.unsubscribers = []
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

  activate() {
    this._initializeIndex();
    this.unsubscribers = [
      // TODO listen for changes in AccountStore
      DatabaseStore.listen(this._onDataChanged),
    ];
  }

  deactivate() {
    this.unsubscribers.forEach(unsub => unsub())
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
        DatabaseStore.indexModel(model, this.getIndexDataForModel(model))
      } else {
        DatabaseStore.unindexModel(model)
      }
    });
  }
}
