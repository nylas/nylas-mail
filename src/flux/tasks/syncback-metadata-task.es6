import SyncbackModelTask from './syncback-model-task'
import DatabaseObjectRegistry from '../../database-object-registry'

export default class SyncbackMetadataTask extends SyncbackModelTask {

  constructor(modelClientId, modelClassName, pluginId) {
    super({clientId: modelClientId});
    this.modelClassName = modelClassName;
    this.pluginId = pluginId;
  }

  getModelConstructor() {
    return DatabaseObjectRegistry.classMap()[this.modelClassName];
  }

  getRequestData = (model) => {
    const metadata = model.metadataObjectForPluginId(this.pluginId);

    return {
      path: `/metadata/${model.id}?client_id=${this.pluginId}`,
      method: 'POST',
      body: {
        object_id: model.serverId,
        object_type: this.modelClassName.toLowerCase(),
        version: metadata.version,
        value: metadata.value,
      },
    };
  };

  applyRemoteChangesToModel = (model, {version}) => {
    const metadata = model.metadataObjectForPluginId(this.pluginId);
    metadata.version = version;
    return model;
  };

}
