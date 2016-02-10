import Model from './model'
import Attributes from '../attributes'

export default class PluginMetadata extends Model {
  static attributes = Object.assign({}, Model.attributes, {
    pluginId: Attributes.String({
      modelKey: 'pluginId',
    }),
    version: Attributes.Number({
      modelKey: 'version',
    }),
    value: Attributes.Object({
      modelKey: 'value',
    }),
  });

  constructor(...args) {
    super(...args)
    this.version = this.version ? this.version : 0;
  }

  queryableValue = ()=> {
    return this.pluginId;
  };
}


/**
 Cloud-persisted data that is associated with a single Nylas API object
 (like a `Thread`, `Message`, or `Account`).

 Each Nylas API object can have exactly one `Metadata` object associated
 with it. If you update the metadata object on an existing associated
 Nylas API object, it will override the previous `value`
*/
export default class ModelWithMetadata extends Model {
  static attributes = Object.assign({}, Model.attributes, {
    pluginMetadata: Attributes.Collection({
      queryable: true,
      modelKey: 'pluginMetadata',
      itemClass: PluginMetadata,
    }),
  });

  constructor(...args) {
    super(...args)
    this.pluginMetadata = this.pluginMetadata ? this.pluginMetadata : [];
  }

  metadataForPluginId = (pluginId)=> {
    return this.pluginMetadata.filter(metadata => metadata.pluginId === pluginId).pop();
  };

  applyPluginMetadata = (pluginId, pluginValue)=> {
    const clone = this.clone();

    let metadata = clone.metadataForPluginId(pluginId);
    if (!metadata) {
      metadata = new PluginMetadata({pluginId});
      clone.pluginMetadata.push(metadata);
    }
    metadata.value = pluginValue;
    return clone;
  };

}
