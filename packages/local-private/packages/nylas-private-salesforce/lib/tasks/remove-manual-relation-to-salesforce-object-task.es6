import {
  Task,
  Actions,
  DatabaseStore,
  SyncbackMetadataTask,
  DatabaseObjectRegistry,
} from 'nylas-exports'
import { PLUGIN_ID } from '../salesforce-constants';
import * as mdHelpers from "../metadata-helpers";

import SyncThreadActivityToSalesforceTask from './sync-thread-activity-to-salesforce-task'

export default class RemoveManualRelationToSalesforceObjectTask extends Task {
  constructor({sObjectId, nylasObjectId, nylasObjectType} = {}) {
    super();
    this.sObjectId = sObjectId
    this.nylasObjectId = nylasObjectId
    this.nylasObjectType = nylasObjectType
    this.metadataUpdated = false
  }

  isSameAndOlderTask(other) {
    return other instanceof RemoveManualRelationToSalesforceObjectTask &&
      other.sObjectId === this.sObjectId &&
      other.nylasObjectId === this.nylasObjectId &&
      other.nylasObjectType === this.nylasObjectType &&
      other.sequentialId < this.sequentialId;
  }

  isDependentOnTask(other) {
    return this.isSameAndOlderTask(other)
  }

  shouldDequeueOtherTask(other) {
    return this.isSameAndOlderTask(other)
  }

  performLocal() {
    return this._loadNylasObject()
    .then(this._updateMetadata)
  }

  performRemote() {
    if (this.metadataUpdated) {
      return this._loadNylasObject
      .then(this._queueSyncbackMetadata)
      .then(this._queueSyncThreadActivity)
      .then(() => Task.Status.Success)
    }
    return Promise.resolve(Task.Status.Success)
  }

  _loadNylasObject() {
    const klass = DatabaseObjectRegistry.get(this.nylasObjectType);
    return DatabaseStore.find(klass, this.nylasObjectId)
  }

  _updateMetadata = (nylasObject) => {
    if (mdHelpers.getManuallyRelatedObjects(nylasObject)[this.sObjectId]) {
      mdHelpers.removeManuallyRelatedObject(nylasObject, {id: this.sObjectId});
      this.metadataUpdated = true
      return DatabaseStore.inTransaction(t => t.persistModel(nylasObject))
    }
    return Promise.resolve()
  }

  _queueSyncbackMetadata = (nylasObject) => {
    const task = new SyncbackMetadataTask(nylasObject.clientId, nylasObject.constructor.name, PLUGIN_ID);
    Actions.queueTask(task);
    return Promise.resolve(nylasObject)
  }

  // When removing a manually related sObject, we also want to stop
  // syncing the thread to it (if we marked it to sync).
  _queueSyncThreadActivity = (nylasObject) => {
    if (mdHelpers.getSObjectsToSyncActivityTo(nylasObject)[this.sObjectId]) {
      const t = new SyncThreadActivityToSalesforceTask({
        threadId: nylasObject.id,
        threadClientId: nylasObject.clientId,
        sObjectsToStopSyncing: [{id: this.sObjectId}],
      });

      Actions.queueTask(t);
    }
    return Promise.resolve()
  }
}
