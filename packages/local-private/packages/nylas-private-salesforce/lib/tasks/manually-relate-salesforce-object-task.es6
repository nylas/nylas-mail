import _ from 'underscore'
import {
  Task,
  Actions,
  DatabaseStore,
  SyncbackMetadataTask,
  DatabaseObjectRegistry,
} from 'nylas-exports'
import { PLUGIN_ID } from '../salesforce-constants';
import * as mdHelpers from "../metadata-helpers";
import * as dataHelpers from "../salesforce-object-helpers";

import UpsertOpportunityContactRoleTask from './upsert-opportunity-contact-role-task'
import SyncThreadActivityToSalesforceTask from './sync-thread-activity-to-salesforce-task'

export default class ManuallyRelateSalesforceObjectTask extends Task {
  constructor(args = {}) {
    super();
    this.args = args;
    this.sObjectId = args.sObjectId
    this.sObjectType = args.sObjectType
    this.nylasObjectId = args.nylasObjectId
    this.syncbackThread = args.syncbackThread
    this.nylasObjectType = args.nylasObjectType
  }

  isSameAndOlderTask(other) {
    return other instanceof ManuallyRelateSalesforceObjectTask &&
      other.sObjectId === this.sObjectId &&
      other.sObjectType === this.sObjectType &&
      other.nylasObjectId === this.nylasObjectId &&
      other.nylasObjectType === this.nylasObjectType &&
      other.sequentialId < this.sequentialId;
  }

  isDependentOnTask(other) {
    return ((other instanceof SyncbackMetadataTask) &&
        (other.modelClassName === "Thread") &&
        (other.pluginId === PLUGIN_ID)) ||
        (other.constructor.name === "SyncbackSalesforceObjectTask" &&
         other.objectId === this.sObjectId &&
         other.objectType === this.sObjectType) ||
        this.isSameAndOlderTask(other)
  }

  shouldDequeueOtherTask(other) {
    return this.isSameAndOlderTask(other)
  }

  performLocal() {
    return Promise.resolve({objectId: this.sObjectId, objectType: this.sObjectType})
    .then(dataHelpers.loadFullObject)
    .then(this._loadNylasObject)
    .then(this._updateMetadata)
  }

  performRemote() {
    return Promise.resolve({objectId: this.sObjectId, objectType: this.sObjectType})
    .then(dataHelpers.loadFullObject)
    .then(this._loadNylasObject)
    .then(this._queueSyncbackMetadata)
    .then(this._queueSyncThreadActivity)
    .then(this._queueRelatedObjectUpsert)
    .then(() => Task.Status.Success)
  }

  _loadNylasObject = (fullSObject) => {
    const klass = DatabaseObjectRegistry.get(this.nylasObjectType);
    return DatabaseStore.find(klass, this.nylasObjectId)
    .then((nylasObject) => { return {nylasObject, fullSObject} })
  }

  _updateMetadata = ({fullSObject, nylasObject}) => {
    mdHelpers.setManuallyRelatedObject(nylasObject, fullSObject);
    return DatabaseStore.inTransaction(t => t.persistModel(nylasObject))
    .then(() => { return {fullSObject, nylasObject} })
  }

  _queueSyncbackMetadata = ({fullSObject, nylasObject}) => {
    const task = new SyncbackMetadataTask(nylasObject.clientId, nylasObject.constructor.name, PLUGIN_ID);
    Actions.queueTask(task);
    return Promise.resolve({fullSObject, nylasObject})
  }

  // When manually relating an sObject, we can optional auto-enable whether
  // we syncback activity to that sObject. If we didn't have this feature
  // users would always have to manually flip the "Sync to this sObject"
  // toggle.
  _queueSyncThreadActivity = ({fullSObject, nylasObject}) => {
    // Make sure we haven't already flagged this as a thread to sync
    if (!mdHelpers.getSObjectsToSyncActivityTo(nylasObject)[fullSObject.id]) {
      if (this.syncbackThread && this.nylasObjectType === "Thread") {
        const t = new SyncThreadActivityToSalesforceTask({
          threadId: this.nylasObjectId,
          threadClientId: nylasObject.clientId,
          newSObjectsToSync: [fullSObject],
          sObjectsToStopSyncing: [],
        });

        Actions.queueTask(t);
      }
    }
    return Promise.resolve({fullSObject, nylasObject})
  }

  // This is reciprocal to code in SyncbackSalesforceObjectTask
  //
  // When we link a Thread to an Opportunity and we know there are
  // Contacts on the Thread, we can link them to this opportunity if
  // they're not attached already. Contacts and Opportunities are
  // connected through OpportunityContactRole objects.
  _queueRelatedObjectUpsert = ({fullSObject, nylasObject}) => {
    if (this.sObjectType === "Opportunity" && this.nylasObjectType === "Thread") {
      return this._queueUpsertOpportunityContactRole({fullSObject, nylasObject})
    }
    return Promise.resolve()
  }

  _queueUpsertOpportunityContactRole = ({nylasObject}) => {
    const contacts = nylasObject.participants.filter((contact) => {
      return !contact.isMe() && !contact.hasSameDomainAsMe()
    })
    const t = new UpsertOpportunityContactRoleTask({
      opportunityId: this.sObjectId,
      emails: _.pluck(contacts, "email"),
    })
    Actions.queueTask(t)
    return Promise.resolve()
  }
}
