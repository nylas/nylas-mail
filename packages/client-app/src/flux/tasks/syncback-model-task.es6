import Task from './task'

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

  validate() {
    this.validateRequiredFields(["clientId"])
    return Promise.resolve()
  }

  canBeUndone() { return false }

  isUndo() { return false }
}
