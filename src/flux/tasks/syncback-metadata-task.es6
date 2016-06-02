import SyncbackModelTask from './syncback-model-task'
import DatabaseObjectRegistry from '../../database-object-registry'

export default class SyncbackMetadataTask extends SyncbackModelTask {

  constructor(modelClientId, modelClassName, pluginId) {
    super({clientId: modelClientId});
    this.modelClassName = modelClassName;
    this.pluginId = pluginId;
  }

  getModelConstructor() {
    return DatabaseObjectRegistry.get(this.modelClassName);
  }

  getRequestData = (model) => {
    if (!model.serverId) {
      throw new Error(`Can't syncback metadata for a ${this.modelClassName} instance that doesn't have a serverId`)
    }

    const metadata = model.metadataObjectForPluginId(this.pluginId);

    return {
      path: `/metadata/${model.serverId}?client_id=${this.pluginId}`,
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
