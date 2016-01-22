import _ from 'underscore'
import Task from './task'
import NylasAPI from '../nylas-api'
import DatabaseStore from '../stores/database-store'

export default class DestroyModelTask extends Task {

  constructor({clientId, modelName, endpoint, accountId} = {}) {
    super()
    this.clientId = clientId
    this.endpoint = endpoint
    this.modelName = modelName
    this.accountId = accountId
  }

  shouldDequeueOtherTask(other) {
    return (other instanceof DestroyModelTask &&
            this.modelName === other.modelName &&
            this.accountId === other.accountId &&
            this.endpoint === other.endpoint &&
            this.clientId === other.clientId)
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
      return DatabaseStore.inTransaction((t) => {
        return t.unpersistModel(model)
      });
    })
  }

  performRemote() {
    if (!this.serverId) {
      throw new Error("Need a serverId to destroy remotely")
    }
    return NylasAPI.makeRequest({
      path: `${this.endpoint}/${this.serverId}`,
      method: "DELETE",
      accountId: this.accountId,
    }).then(() => {
      return Promise.resolve(Task.Status.Success)
    }).catch(this.apiErrorHandler)
  }

  canBeUndone() { return true }

  isUndo() { return !!this._isUndoTask }

  createUndoTask() {
    const CreateModelTask = require('./create-model-task')
    const undoTask = new CreateModelTask({
      data: this.oldModel,
      modelName: this.modelName,
      endpoint: this.endpoint,
      accountId: this.accountId,
    })
    undoTask._isUndoTask = true
    return undoTask
  }
}
