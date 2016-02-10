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
    const models = model instanceof Array ? model : [models]
    const updatedModels = model.map(m => m.applyPluginMetadata(pluginId, pluginData))

    DatabaseStore.inTransaction((t)=> {
      t.persistModels(updatedModels);
    }).then(()=> {
      updatedModels.forEach((updated)=> {
        if (updated.isSaved()) {
          const task = new SyncbackMetadataTask(updated.clientId, updated.constructor.name, pluginId);
          Actions.queueTask(task);
        } else {
          // TODO we'll syncback metadata after the object is saved
          // Maybe move this into the task
        }
      })
    });
  }
}
module.exports = new MetadataStore();
