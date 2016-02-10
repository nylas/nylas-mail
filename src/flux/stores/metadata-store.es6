import NylasStore from 'nylas-store';
import Actions from '../actions';
import DatabaseStore from './database-store';
import SyncbackMetadataTask from '../tasks/syncback-metadata-task';

class MetadataStore extends NylasStore {

  constructor() {
    super();
    this.listenTo(Actions.setMetadata, this._setMetadata);
  }

  _setMetadata(modelOrModels, pluginId, pluginData) {
    const models = (modelOrModels instanceof Array) ? modelOrModels : [modelOrModels];
    const updatedModels = models.map(m => m.applyPluginMetadata(pluginId, pluginData));

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
