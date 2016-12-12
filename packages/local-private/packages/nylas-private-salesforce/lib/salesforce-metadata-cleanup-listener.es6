import {
  Thread,
  Message,
  Actions,
  DatabaseStore,
  SyncbackMetadataTask,
} from 'nylas-exports'
import {PLUGIN_ID} from './salesforce-constants'
import SalesforceObject from './models/salesforce-object'
import * as mdHelpers from './metadata-helpers'
import SyncThreadActivityToSalesforceTask from './tasks/sync-thread-activity-to-salesforce-task'
import RemoveManualRelationToSalesforceObjectTask from './tasks/remove-manual-relation-to-salesforce-object-task'


/**
 * When sObjects get deleted from the database, we need to cleanup their
 * references in our metadata.
 *
 * If we've manually related sObjects and/or are trying to sync thread
 * activity with them, we need to spawn tasks that clear these when
 * sObjects get deleted.
 *
 */
class SalesforceMetadataCleanupListener {
  constructor() {
    this._unsubscribers = []
  }

  activate() {
    this._unsubscribers = [
      DatabaseStore.listen(this._onDataChanged),
    ]
  }

  deactivate() {
    this._unsubscribers.forEach((usub) => usub())
  }

  _onDataChanged = (change) => {
    if (change.objectClass !== SalesforceObject.name) return;
    if (change.type !== 'unpersist') {
      this._onSObjectsDeleted(change.objects)
    }
  }

  _onSObjectsDeleted = (deletedSObjects) => {
    DatabaseStore.findAll(Thread)
    .where(Thread.attributes.pluginMetadata.contains(PLUGIN_ID))
    .then((threads) => {
      for (const thread of threads) {
        for (const deletedSObject of deletedSObjects) {
          this._cleanupThread(thread, deletedSObject)
        }
      }
    })

    DatabaseStore.findAll(Message)
    .where(Message.attributes.pluginMetadata.contains(PLUGIN_ID))
    .then((messages) => {
      for (const message of messages) {
        for (const deletedSObject of deletedSObjects) {
          this._cleanupMessage(message, deletedSObject)
        }
      }
    })
  }

  // If we're syncing a thread with an sObject that just got deleted, stop
  // syncing with that sObject.
  _cleanupThread = (thread, deletedSObject) => {
    // A thread might be manually related to the recently deleted sObject.
    // Be sure to clean that up
    if (mdHelpers.getManuallyRelatedObjects(thread)[deletedSObject.id]) {
      const t = new RemoveManualRelationToSalesforceObjectTask({
        sObjectId: deletedSObject.id,
        sObjectType: deletedSObject.type,
        nylasObjectId: thread.id,
        nylasObjectType: thread.type,
      })
      Actions.queueTask(t)
    } else if (mdHelpers.getSObjectsToSyncActivityTo(thread)[deletedSObject.id]) {
      // Note, this is an ELSE if, because the
      // RemoveManualRelationToSalesforceObjectTask automatically checks
      // if we've enabled sync witht that thread. If so it'll do the same
      // thing and mark the thread to stop syncing.
      //
      // It's common for us to be syncing with threads that were
      // automatically related and have no records in our "manually
      // related" objects.
      const t = new SyncThreadActivityToSalesforceTask({
        threadId: thread.id,
        threadClientId: thread.clientId,
        sObjectsToStopSyncing: [deletedSObject],
      })
      Actions.queueTask(t)
    }
    return Promise.resolve()
  }

  _cleanupMessage = (message, deletedSObject) => {
    const relatedToId = mdHelpers.relatedIdForClonedSObject(message, deletedSObject)
    if (relatedToId) {
      const relatedSObject = {id: relatedToId}
      const sObjectToRemove = {id: relatedToId}
      mdHelpers.removeClonedSObject(message, relatedSObject, sObjectToRemove);
      return DatabaseStore.inTransaction(t => t.persistModel(message))
      .then(() => {
        const t = new SyncbackMetadataTask(message.clientId, message.constructor.name, PLUGIN_ID);
        Actions.queueTask(t);
      })
    }
    return Promise.resolve()
  }
}
export default new SalesforceMetadataCleanupListener()
