import NylasStore from 'nylas-store';
import Actions from '../actions';
import DatabaseStore from './database-store';
import SyncbackMetadataTask from '../tasks/syncback-metadata-task';

class MetadataStore extends NylasStore {

  constructor() {
    super();
    this.listenTo(Actions.setMetadata, this._setMetadata);
  }

  _setMetadata(model, pluginId, pluginData) {
    const updated = model.applyPluginMetadata(pluginId, pluginData);

    DatabaseStore.inTransaction((t)=> {
      t.persistModel(updated);
    }).then(()=> {
      if (updated.isSaved()) {
        const task = new SyncbackMetadataTask(updated.clientId, updated.constructor.name, pluginId);
        Actions.queueTask(task);
      } else {
        // we'll syncback metadata after the object is saved
      }
    });
  }
}
module.exports = new MetadataStore();
