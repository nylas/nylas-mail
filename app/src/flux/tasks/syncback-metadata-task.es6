import Task from './task';
import Attributes from '../attributes';

export default class SyncbackMetadataTask extends Task {

  static attributes = Object.assign({}, Task.attributes, {
    pluginId: Attributes.String({
      modelKey: 'pluginId',
    }),
    modelId: Attributes.String({
      modelKey: 'modelId',
    }),
    modelClassName: Attributes.String({
      modelKey: 'modelClassName',
    }),
    modelHeaderMessageId: Attributes.String({
      modelKey: 'modelHeaderMessageId',
    }),
    value: Attributes.Object({
      modelKey: 'value',
    }),
  });

  constructor(data = {}) {
    super(data);
    if (data.model) {
      this.modelId = data.model.id;
      this.modelClassName = data.model.constructor.name.toLowerCase();
      this.modelHeaderMessageId = data.model.headerMessageId || null;
      this.accountId = data.model.accountId;
    }
  }
}
