import _ from 'underscore'
import Task from './task'
import NylasAPI from '../nylas-api'
import NylasAPIRequest from '../nylas-api-request'
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

  canBeUndone() { return false }

  isUndo() { return false }
}
