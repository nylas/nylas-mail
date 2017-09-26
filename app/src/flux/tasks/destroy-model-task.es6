/* eslint global-require:0 */
import Task from './task';

export default class DestroyModelTask extends Task {
  constructor({ clientId, modelName, endpoint, accountId } = {}) {
    super();
    this.clientId = clientId;
    this.endpoint = endpoint;
    this.modelName = modelName;
    this.accountId = accountId;
  }

  shouldDequeueOtherTask(other) {
    return (
      other instanceof DestroyModelTask &&
      this.modelName === other.modelName &&
      this.accountId === other.accountId &&
      this.endpoint === other.endpoint &&
      this.clientId === other.clientId
    );
  }

  getModelConstructor() {
    return require('nylas-exports')[this.modelName];
  }

  validate() {}
}
