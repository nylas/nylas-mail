import { Task, DatabaseStore } from 'nylas-exports'
import SalesforceAPI from '../salesforce-api'
import SalesforceObject from '../models/salesforce-object'

/**
 * Attempts to delete a Salesforce Object remotely and then locally from
 * N1.
 *
 * Note that when sObjects get deleted from our Database, the
 * SalesforceRelatedObjectCache listens for those changes and queues the
 * appropriate cleanup tasks.
 *
 * For example, if we delete an Opportunity, we want to cleanup any manual
 * relations we've setup and stop trying to sync emails to it.
 *
 * If we delete a Salesforce Task, we want to remove that Task from the
 * corresponding paired Message (if any).
 */
export default class DestroySalesforceObjectTask extends Task {
  constructor(args = {}) {
    super();
    this.args = args;
    this.sObjectId = args.sObjectId
    this.sObjectType = args.sObjectType
  }

  isSameAndOlderTask(other) {
    return other instanceof DestroySalesforceObjectTask &&
      other.sObjectId === this.sObjectId &&
      other.sObjectType === this.sObjectType &&
      other.sequentialId < this.sequentialId;
  }

  shouldDequeueOtherTask(other) {
    return this.isSameAndOlderTask(other)
  }

  isDependentOnTask(other) {
    return this.isSameAndOlderTask(other)
  }

  performLocal() {
    return Promise.resolve()
  }

  performRemote() {
    return SalesforceAPI.makeRequest({
      method: "DELETE",
      path: `/sobjects/${this.sObjectType}/${this.sObjectId}`,
    })
    .then(this._removeLocally)
    .catch((err = {}) => {
      if (err.statusCode === 404) return this._removeLocally()
      throw err
    })
    .then(() => Task.Status.Success);
  }

  _removeLocally = () => {
    return DatabaseStore.findBy(SalesforceObject,
        {id: this.sObjectId, type: this.sObjectType})
    .then((obj) => (
      DatabaseStore.inTransaction(t => t.unpersistModel(obj))
    ))
  }
}
