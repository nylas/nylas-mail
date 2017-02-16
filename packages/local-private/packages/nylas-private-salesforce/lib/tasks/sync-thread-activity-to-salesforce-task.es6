import {
  Task,
  Thread,
  Message,
  Actions,
  DatabaseStore,
  SyncbackMetadataTask,
} from 'nylas-exports'
import {PLUGIN_ID} from '../salesforce-constants'
import * as mdHelpers from '../metadata-helpers'
import EnsureMessageOnSalesforceTask from './ensure-message-on-salesforce-task'
import DestroyMessageOnSalesforceTask from './destroy-message-on-salesforce-task'

/**
 * Given a threadId, this will load all of the messages on the thread and
 * make sure that there are EmailMessages associated with each of the
 * correspondingly linked SalesforceObjects
 *
 * See lib/metadata-helpers.es6 for documentation on what metadata on the
 * object looks like.
 *
 */
export default class SyncThreadActivityToSalesforceTask extends Task {
  constructor({threadId, threadClientId, newSObjectsToSync, sObjectsToStopSyncing} = {}) {
    super();
    this.threadId = threadId;
    this.isCanceled = false;
    this.threadClientId = threadClientId;
    this.newSObjectsToSync = newSObjectsToSync || [];
    this.sObjectsToStopSyncing = sObjectsToStopSyncing || [];
  }

  isSameAndOlderTask(other) {
    return other instanceof SyncThreadActivityToSalesforceTask &&
      other.threadId === this.threadId &&
      other.threadClientId === this.threadClientId &&
      other.sequentialId < this.sequentialId;
  }

  shouldDequeueOtherTask(other) {
    return this.isSameAndOlderTask(other)
  }

  isDependentOnTask(other) {
    return (other instanceof SyncbackMetadataTask) &&
      (other.modelClassName === "Thread") &&
      (other.clientId === this.threadClientId) &&
      (other.pluginId === PLUGIN_ID) ||
      this.isSameAndOlderTask(other);
  }

  performLocal() {
    return this._loadThread()
    .then(this._updateMetadata)
  }

  performRemote() {
    return this._loadThread()
    .then(this._queueSyncbackMetadata)
    .then(this._queueMessageTasks)
    .thenReturn(Task.Status.Success)
  }

  cancel() {
    this.isCanceled = true;
  }

  _loadThread = () => {
    return DatabaseStore.find(Thread, this.threadId)
  }

  _updateMetadata = (thread) => {
    for (const newSObject of this.newSObjectsToSync) {
      mdHelpers.addActivitySyncSObject(thread, newSObject);
    }

    for (const sObject of this.sObjectsToStopSyncing) {
      mdHelpers.removeActivitySyncSObject(thread, sObject);
    }

    return DatabaseStore.inTransaction(t => t.persistModel(thread))
    .then(() => thread)
  }

  _queueSyncbackMetadata = (thread) => {
    if (this.isCanceled) return Promise.resolve(thread);
    const task = new SyncbackMetadataTask(thread.clientId, thread.constructor.name, PLUGIN_ID);
    Actions.queueTask(task);
    return Promise.resolve(thread)
  }

  _queueMessageTasks = (thread) => {
    if (this.isCanceled) return Promise.resolve(thread);
    const sObjectsToSync = mdHelpers.getSObjectsToSyncActivityTo(thread);
    if (Object.keys(sObjectsToSync).length === 0 && this.sObjectsToStopSyncing.length === 0) {
      return Promise.resolve()
    }

    // Since we don't need the very expensive bodies!
    const basicMsgQuery = DatabaseStore.findAll(Message).where({threadId: thread.id})
    return Promise.each(basicMsgQuery, (message) => {
      if (this.isCanceled) return;
      for (const sObjectToStopSyncing of this.sObjectsToStopSyncing) {
        const t = new DestroyMessageOnSalesforceTask({
          messageId: message.id,
          sObjectId: sObjectToStopSyncing.id,
        })
        Actions.queueTask(t);
      }

      for (const sObjectId of Object.keys(sObjectsToSync)) {
        const t = new EnsureMessageOnSalesforceTask({
          messageId: message.id,
          sObjectId: sObjectId,
          sObjectType: sObjectsToSync[sObjectId].type,
        })
        Actions.queueTask(t);
      }
    })
  }
}
