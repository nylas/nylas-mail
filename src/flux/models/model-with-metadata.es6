import Model from './model'
import Attributes from '../attributes'

export default class PluginMetadata extends Model {
  static attributes = Object.assign({}, Model.attributes, {
    pluginId: Attributes.String({
      modelKey: 'pluginId'
    }),
    version: Attributes.Number({
      modelKey: 'version'
    }),
    value: Attributes.Object({
      modelKey: 'value'
    }),
  });

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
    })
  });

  metadataForPluginId = (pluginId)=> {
    if (!this.pluginMetadata) {
      this.pluginMetadata = [];
    }
    return this.pluginMetadata.filter(metadata => metadata.pluginId === pluginId).pop();
  };

  applyPluginMetadata = (pluginId, pluginValue)=> {
    clone = this.clone();

    metadata = clone.metadataForPluginId(pluginId);
    if (!metadata) {
      metadata = new PluginMetadata({pluginId, version: 0});
      clone.pluginMetadata.push(metadata);
    }
    metadata.value = pluginValue;
    return clone;
  }

}
