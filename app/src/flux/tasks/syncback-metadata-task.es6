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

    if (data.value && data.value.expiration) {
      data.value.expiration = Math.round(new Date(data.value.expiration).getTime() / 1000);
    }

    if (data.model) {
      this.modelId = data.model.id;
      this.modelClassName = data.model.constructor.name.toLowerCase();
      this.modelHeaderMessageId = data.model.headerMessageId || null;
      this.accountId = data.model.accountId;
    }
  }

  validate() {
    if (!this.pluginId) {
      throw new Error("SyncbackMetadataTask: You must specify a pluginId.");
    }
    return super.validate();
  }
}
