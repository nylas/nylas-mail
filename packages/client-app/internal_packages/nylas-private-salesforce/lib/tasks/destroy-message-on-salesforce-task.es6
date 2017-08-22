import _ from 'underscore'
import {
  Task,
  Utils,
  Message,
  Actions,
  DatabaseStore,
  SyncbackMetadataTask,
} from 'nylas-exports'

import {PLUGIN_ID} from '../salesforce-constants'
import SalesforceAPI from '../salesforce-api'
import * as mdHelpers from '../metadata-helpers'

export default class DestroyMessageOnSalesforceTask extends Task {
  constructor({messageId, sObjectId} = {}) {
    super()
    this.messageId = messageId;
    this.sObjectId = sObjectId;
    this.isCanceled = false;
  }

  isSameAndOlderTask(other) {
    return other instanceof DestroyMessageOnSalesforceTask &&
      other.messageId === this.messageId &&
      other.sequentialId < this.sequentialId;
  }

  isComplementTask(other) {
    return other.constructor.name === "EnsureMessageOnSalesforceTask" &&
      other.messageId === this.messageId &&
      other.sequentialId < this.sequentialId;
  }

  shouldDequeueOtherTask(other) {
    return this.isSameAndOlderTask(other) || this.isComplementTask(other);
  }

  isDependentOnTask(other) {
    return this.isSameAndOlderTask(other) || this.isComplementTask(other);
  }

  performLocal() {
    return DatabaseStore.find(Message, this.messageId)
    .then(this._markPendingStatus)
  }

  performRemote() {
    return DatabaseStore.find(Message, this.messageId)
    .then(this._deleteClonedSObjects)
    .thenReturn(Task.Status.Success)
  }

  cancel() {
    this.isCanceled = true;
  }

  _deleteClonedSObjects = (message) => {
    if (this.isCanceled) return Promise.resolve();
    const clonedAs = _.values(mdHelpers.getClonedAsForSObject(message, {
      id: this.sObjectId}));
    if (clonedAs.length === 0) return Promise.resolve();
    return Promise.each(clonedAs, (clonedSObject) => {
      if (this.isCanceled) return Promise.resolve();
      return SalesforceAPI.makeRequest({
        method: "DELETE",
        path: `/sobjects/${clonedSObject.type}/${clonedSObject.id}`,
      })
      .catch((apiError) => {
        if (apiError.errorCode === "ENTITY_IS_DELETED") {
          return Promise.resolve(); // go ahead and remove from metadata
        }
        throw apiError
      })
      .then(() => {
        mdHelpers.removeClonedSObject(message,
            {id: this.sObjectId}, {id: clonedSObject.id})
      })
    }).finally(() => { this._syncbackMetadata(message) })
  }

  _syncbackMetadata = (message) => {
    const metadata = Utils.deepClone(message.metadataForPluginId(PLUGIN_ID));
    metadata.pendingSync = false;
    message.applyPluginMetadata(PLUGIN_ID, metadata);
    return DatabaseStore.inTransaction(t => t.persistModel(message))
    .then(() => {
      const task = new SyncbackMetadataTask(message.clientId, "Message", PLUGIN_ID);
      Actions.queueTask(task);
    })
  }

  _markPendingStatus = (message) => {
    const metadata = Utils.deepClone(message.metadataForPluginId(PLUGIN_ID) || {});
    metadata.pendingSync = true
    message.applyPluginMetadata(PLUGIN_ID, metadata);
    return DatabaseStore.inTransaction(t => t.persistModel(message))
  }
}
