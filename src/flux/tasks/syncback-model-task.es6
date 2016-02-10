import _ from 'underscore'
import Task from './task'
import NylasAPI from '../nylas-api'
import {APIError} from '../errors'
import DatabaseStore from '../stores/database-store'

export default class SyncbackModelTask extends Task {

  constructor({clientId, endpoint} = {}) {
    super()
    this.clientId = clientId
    this.endpoint = endpoint
  }

  shouldDequeueOtherTask(other) {
    return (other instanceof SyncbackModelTask &&
            this.clientId === other.clientId)
  }

  getModelConstructor() {
    throw new Error("You must subclass and implement `getModelConstructor`. Return a constructor class")
  }

  performLocal() {
    this.validateRequiredFields(["clientId"])
    return Promise.resolve()
  }

  performRemote() {
    return Promise.resolve()
    .then(this.getLatestModel)
    .then(this.verifyModel)
    .then(this.makeRequest)
    .then(this.updateLocalModel)
    .thenReturn(Task.Status.Success)
    .catch(this.handleRemoteError)
  }

  getLatestModel = () => {
    return DatabaseStore.findBy(this.getModelConstructor(),
                                {clientId: this.clientId})
  }

  verifyModel = (model) => {
    if (model) {
      return Promise.resolve(model)
    }
    throw new Error(`Can't find a '${this.getModelConstructor().name}' model for clientId: ${this.clientId}'`)
  }

  makeRequest = (model) => {
    const options = _.extend({
      accountId: model.accountId,
      returnsModel: false,
    }, this.getRequestData(model));

    return NylasAPI.makeRequest(options);
  }

  getRequestData = (model) => {
    if (model.isSaved()) {
      return {
        path: `${this.endpoint}/${model.serverId}`,
        body: model.toJSON(),
        method: "PUT",
      }
    }
    return {
      path: `${this.endpoint}`,
      body: model.toJSON(),
      method: "POST",
    }
  }

  updateLocalModel = (responseJSON) => {
    /*
    Important: There could be a significant delay between us initiating
    the save and getting JSON back from the server. Our local copy of
    the model may have already changed more.

    The only fields we want to update from the server are the `id` and
    `version`.
    */
    return DatabaseStore.inTransaction((t) => {
      return this.getLatestModel().then((model) => {
        // Model may have been deleted
        if (!model) { return Promise.resolve() }
        const changed = this.applyRemoteChangesToModel(model, responseJSON);
        return t.persistModel(changed);
      })
    }).thenReturn(true)
  }

  applyRemoteChangesToModel = (model, {version, id}) => {
    model.version = version;
    model.serverId = id;
    return model;
  }

  handleRemoteError = (err) => {
    if (err instanceof APIError) {
      if (NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
        return Promise.resolve([Task.Status.Failed, err])
      }
      if (err.statusCode === 409) {
        return this.handleRemoteVersionConflict(err);
      }
      return Promise.resolve(Task.Status.Retry)
    }

    NylasEnv.reportError(err);
    return Promise.resolve([Task.Status.Failed, err])
  }

  handleRemoteVersionConflict = (err) => {
    return Promise.resolve([Task.Status.Failed, err])
  }

  canBeUndone() { return false }

  isUndo() { return false }
}
