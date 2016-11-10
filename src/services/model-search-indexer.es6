import { DatabaseStore } from 'nylas-exports';

export default class ModelSearchIndexer {
  constructor() {
    this.unsubscribers = []
  }

  modelClass() {
    throw new Error("Override me and return a class constructor")
  }

  configKey() {
    throw new Error("Override me and return a string config key")
  }

  getIndexDataForModel() {
    throw new Error("Override me and return a hash with a `content` array")
  }

  INDEX_VERSION() {
    throw new Error("Override me and return an INDEX_VERSION")
  }

  activate() {
    this._initializeIndex();
    this.unsubscribers = [
      DatabaseStore.listen(this._onDataChanged),
    ];
  }

  deactivate() {
    this.unsubscribers.forEach(unsub => unsub())
  }

  _initializeIndex() {
    if (NylasEnv.config.get(this.configKey()) !== this.INDEX_VERSION()) {
      DatabaseStore.dropSearchIndex(this.modelClass())
      .then(() => DatabaseStore.createSearchIndex(this.modelClass()))
      .then(() => this._buildIndex())
    }
  }

  _buildIndex(offset = 0) {
    const indexingPageSize = 1000;
    const indexingPageDelay = 1000;

    DatabaseStore.findAll(this.modelClass())
    .limit(indexingPageSize)
    .offset(offset)
    .then((models) => {
      if (models.length === 0) {
        NylasEnv.config.set(this.configKey(), this.INDEX_VERSION())
        return;
      }
      Promise.each(models, (model) => {
        return DatabaseStore.indexModel(model, this.getIndexDataForModel(model))
      }).then(() => {
        setTimeout(() => {
          this._buildIndex(offset + models.length);
        }, indexingPageDelay);
      });
    });
  }

  /**
   * When a model gets updated we will update the search index with the
   * data from that model if the account it belongs to is not being
   * currently synced.
   */
  _onDataChanged = (change) => {
    if (change.objectClass !== this.modelClass().name) {
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
