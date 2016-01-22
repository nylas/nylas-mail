import _ from 'underscore'
import Task from './task'
import NylasAPI from '../nylas-api'
import DatabaseStore from '../stores/database-store'

export default class CreateModelTask extends Task {

  constructor({data = {}, modelName, endpoint, requiredFields = [], accountId} = {}) {
    super()
    this.data = data
    this.endpoint = endpoint
    this.modelName = modelName
    this.accountId = accountId
    this.requiredFields = requiredFields || []
  }

  shouldDequeueOtherTask(other) {
    return (other instanceof CreateModelTask &&
            this.modelName === other.modelName &&
            this.accountId === other.accountId &&
            this.endpoint === other.endpoint &&
            _.isEqual(this.data, other.data))
  }

  getModelConstructor() {
    return require('nylas-exports')[this.modelName]
  }

  performLocal() {
    this.validateRequiredFields(["accountId", "endpoint"])

    for (const field of this.requiredFields) {
      if (this.data[field] === null || this.data[field] === undefined) {
        throw new Error(`Must pass data field "${field}"`)
      }
    }

    const Klass = require('nylas-exports')[this.modelName]
    if (!_.isFunction(Klass)) {
      throw new Error(`Couldn't find the class for ${this.modelName}`)
    }

    this.model = new Klass(this.data)
    return DatabaseStore.inTransaction((t) => {
      return t.persistModel(this.model)
    });
  }

  performRemote() {
    return NylasAPI.makeRequest({
      path: this.endpoint,
      method: "POST",
      accountId: this.accountId,
      body: this.model.toJSON(),
      returnsModel: true,
    }).then(() => {
      return Promise.resolve(Task.Status.Success)
    }).catch(this.apiErrorHandler)
  }

  canBeUndone() { return true }

  isUndo() { return !!this._isUndoTask }

  createUndoTask() {
    const DestroyModelTask = require('./destroy-model-task')
    const undoTask = new DestroyModelTask({
      clientId: this.model.clientId,
      modelName: this.modelName,
      endpoint: this.endpoint,
      accountId: this.accountId,
    })
    undoTask._isUndoTask = true
    return undoTask
  }
}
