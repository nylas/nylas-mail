import _ from 'underscore'
import Task from './task'
import NylasAPI from '../nylas-api'
import DatabaseStore from '../stores/database-store'

export default class UpdateModelTask extends Task {

  constructor({clientId, newData = {}, modelName, endpoint, accountId} = {}) {
    super()
    this.clientId = clientId
    this.newData = newData
    this.endpoint = endpoint
    this.modelName = modelName
    this.accountId = accountId
  }

  shouldDequeueOtherTask(other) {
    return (other instanceof UpdateModelTask &&
            this.clientId === other.clientId &&
            this.modelName === other.modelName &&
            this.accountId === other.accountId &&
            this.endpoint === other.endpoint &&
            _.isEqual(this.newData, other.newData))
  }

  getModelConstructor() {
    return require('nylas-exports')[this.modelName]
  }

  performLocal() {
    this.validateRequiredFields(["clientId", "accountId", "endpoint"])

    const klass = this.getModelConstructor()
    if (!_.isFunction(klass)) {
      throw new Error(`Couldn't find the class for ${this.modelName}`)
    }

    return DatabaseStore.findBy(klass, {clientId: this.clientId}).then((model) => {
      if (!model) {
        throw new Error(`Couldn't find the model with clientId ${this.clientId}`)
      }
      this.serverId = model.serverId
      this.oldModel = model.clone()
      const updatedModel = _.extend(model, this.newData)
      return DatabaseStore.inTransaction((t) => {
        return t.persistModel(updatedModel)
      });
    });
  }

  performRemote() {
    if (!this.serverId) {
      throw new Error("Need a serverId to update remotely")
    }
    return NylasAPI.makeRequest({
      path: `${this.endpoint}/${this.serverId}`,
      method: "PUT",
      accountId: this.accountId,
      body: this.newData,
      returnsModel: true,
    }).then(() => {
      return Promise.resolve(Task.Status.Success)
    }).catch(this.apiErrorHandler)
  }

  canBeUndone() { return true }

  isUndo() { return !!this._isUndoTask }

  createUndoTask() {
    const undoTask = new UpdateModelTask({
      clientId: this.clientId,
      newData: this.oldModel,
      modelName: this.modelName,
      endpoint: this.endpoint,
      accountId: this.accountId,
    })
    undoTask._isUndoTask = true
    return undoTask
  }
}
