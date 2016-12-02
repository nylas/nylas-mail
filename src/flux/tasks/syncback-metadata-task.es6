import SyncbackModelTask from './syncback-model-task'
import DatabaseObjectRegistry from '../../registries/database-object-registry'
import N1CloudAPI from '../../n1-cloud-api'
import NylasAPIRequest from '../nylas-api-request'

export default class SyncbackMetadataTask extends SyncbackModelTask {

  constructor(modelClientId, modelClassName, pluginId) {
    super({clientId: modelClientId});
    this.modelClassName = modelClassName;
    this.pluginId = pluginId;
  }

  getModelConstructor() {
    return DatabaseObjectRegistry.get(this.modelClassName);
  }

  makeRequest = (model) => {
    if (!model.serverId) {
      throw new Error(`Can't syncback metadata for a ${this.modelClassName} instance that doesn't have a serverId`)
    }
    const metadata = model.metadataObjectForPluginId(this.pluginId);

    try {
      const options = {
        accountId: model.accountId,
        returnsModel: false,
        path: `/metadata/${model.serverId}/${this.pluginId}`,
        method: 'POST',
        body: {
          version: metadata.version,
          value: JSON.stringify(metadata.value),
          objectType: this.modelClassName.toLowerCase(),
        },
      };
      return new NylasAPIRequest({
        api: N1CloudAPI,
        options,
      }).run()
    } catch (error) {
      return Promise.reject(error)
    }
  }

  applyRemoteChangesToModel = (model, {version}) => {
    const metadata = model.metadataObjectForPluginId(this.pluginId);
    metadata.version = version;
    return model;
  };

}
