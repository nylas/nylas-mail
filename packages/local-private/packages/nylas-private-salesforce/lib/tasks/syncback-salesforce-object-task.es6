import _ from 'underscore'
import {Task, Utils, Actions, DatabaseStore} from 'nylas-exports'
import { PLUGIN_ID } from '../salesforce-constants';
import SalesforceAPI from '../salesforce-api'
import SalesforceObject from '../models/salesforce-object'
import SalesforceActions from '../salesforce-actions'
import * as dataHelpers from '../salesforce-object-helpers'
import DestroySalesforceObjectTask from './destroy-salesforce-object-task'

export default class SyncbackSalesforceObjectTask extends Task {
  constructor({objectId, objectType, formPostData, contextData, relatedObjectsData} = {}) {
    super()
    this.objectId = objectId
    this.objectType = objectType
    this.contextData = contextData || {}
    this.formPostData = formPostData || {}
    this.relatedObjectsData = relatedObjectsData || {}
  }

  isDependentOnTask(other) {
    return ((other.constructor.name === "SyncbackMetadataTask") &&
        (other.modelClassName === "Thread") &&
        (other.pluginId === PLUGIN_ID))
  }

  shouldDequeueOtherTask(other) {
    return other instanceof SyncbackSalesforceObjectTask &&
      other.objectId === this.objectId &&
      other.objectType === this.objectType &&
      Utils.isEqual(other.contextData, this.contextData) &&
      Utils.isEqual(other.formPostData, this.formPostData) &&
      Utils.isEqual(other.relatedObjectsData, this.relatedObjectsData)
  }

  performRemote() {
    return Promise.resolve()
    .then(this.submitToSalesforce)
    .then(this.loadAndSaveFullObject)
    .then(this.upsertRelatedObjects)
    .then(this.notifySuccess)
    .then(() => Task.Status.Success)
    .catch(this.handleError)
  }

  submitToSalesforce = () => {
    // If the objectId is present that means we're updating with new data.
    // If it's blank, that means we're creating a new one.
    const method = this.objectId ? "PATCH" : "POST";
    const oidPath = this.objectId != null ? this.objectId : "";
    const path = `/sobjects/${this.objectType}/${oidPath}`;
    return SalesforceAPI.makeRequest({
      path,
      method,
      body: this.formPostData,
    })
  }

  // When you create an object on Salesforce, it returns a stub object
  // with the new id according to the schema here:
  // https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/dome_sobject_create.htm
  loadAndSaveFullObject = (sfCreatedObj = {}) => {
    const objectId = this.objectId || sfCreatedObj.id
    // Note: After we request the full object from the API we save it to
    // the Database here:
    return dataHelpers.requestFullObjectFromAPI({objectType: this.objectType, objectId});
  }

  // When we Create a Contact and there's an Opportunity present, we also
  // connect the newly created Contact to that Opportunity via a special
  // `OpportunityContactRole` object.
  //
  // This is reciprocal to code in ManuallyRelateSalesforceObjectTask
  upsertRelatedObjects = (sObject) => {
    const updates = []
    if (sObject.type === "Contact" &&
        this.relatedObjectsData.OpportunityIds) {
      updates.push(this._setOpportunitiesForContact(sObject))
    } else if (sObject.type === "Opportunity" &&
        this.relatedObjectsData.ContactIds) {
      updates.push(this._setContactsForOpportunity(sObject))
    } else if (sObject.type === "Account" &&
        this.relatedObjectsData.ContactIds) {
      updates.push(this._setContactsForAccount(sObject))
    }
    return Promise.all(updates).then(() => sObject)
  }

  _setOpportunitiesForContact(contact) {
    return DatabaseStore.findAll(SalesforceObject, {
      type: "OpportunityContactRole",
      identifier: contact.id,
    }).then((roles = []) => {
      const existingOppIds = _.pluck(roles, "relatedToId");
      const desiredOppIds = this.relatedObjectsData.OpportunityIds;

      const rolesToDelete = roles.filter(role => {
        return !(desiredOppIds.includes(role.relatedToId))
      })

      const oppIdsToCreate = desiredOppIds.filter((oid) => {
        return !(existingOppIds.includes(oid))
      })

      const tasks = []
      for (const oppId of oppIdsToCreate) {
        tasks.push(new SyncbackSalesforceObjectTask({
          objectType: "OpportunityContactRole",
          formPostData: {
            OpportunityId: oppId,
            ContactId: contact.id,
          },
        }))
      }
      for (const role of rolesToDelete) {
        tasks.push(new DestroySalesforceObjectTask({
          sObjectType: "OpportunityContactRole",
          sObjectId: role.id,
        }))
      }
      if (tasks.length === 0) return;
      Actions.queueTasks(tasks);
    })
  }

  _setContactsForOpportunity(opp) {
    return DatabaseStore.findAll(SalesforceObject, {
      type: "OpportunityContactRole",
      relatedToId: opp.id,
    }).then((roles = []) => {
      const existingContactIds = _.pluck(roles, "identifier");
      const desiredContactIds = this.relatedObjectsData.ContactIds;

      const rolesToDelete = roles.filter(role => {
        return !(desiredContactIds.includes(role.identifier))
      })

      const contactIdsToCreate = desiredContactIds.filter((cid) => {
        return !(existingContactIds.includes(cid))
      })

      const tasks = []
      for (const cid of contactIdsToCreate) {
        tasks.push(new SyncbackSalesforceObjectTask({
          objectType: "OpportunityContactRole",
          formPostData: {
            OpportunityId: opp.id,
            ContactId: cid,
          },
        }))
      }
      for (const role of rolesToDelete) {
        tasks.push(new DestroySalesforceObjectTask({
          sObjectType: "OpportunityContactRole",
          sObjectId: role.id,
        }))
      }
      if (tasks.length === 0) return;
      Actions.queueTasks(tasks);
    })
  }

  // An Account must have the following Contacts. Therefore we need to
  // update Contact objects to have the correct AccountId
  _setContactsForAccount(account) {
    return DatabaseStore.findAll(SalesforceObject, {
      type: "Contact",
      relatedToId: account.id,
    }).then((contacts = []) => {
      const existingContactIds = _.pluck(contacts, "id");
      const desiredContactIds = this.relatedObjectsData.ContactIds;

      const contactsToRemoveAccount = contacts.filter(c => {
        return !(desiredContactIds.includes(c.relatedToId))
      })

      const contactsToAddAccount = desiredContactIds.filter((cid) => {
        return !(existingContactIds.includes(cid))
      })

      const tasks = []
      for (const cid of contactsToAddAccount) {
        tasks.push(new SyncbackSalesforceObjectTask({
          objectType: "Contact",
          objectId: cid,
          formPostData: { AccountId: account.id },
        }))
      }
      for (const contact of contactsToRemoveAccount) {
        tasks.push(new SyncbackSalesforceObjectTask({
          objectType: "Contact",
          objectId: contact.id,
          formPostData: { AccountId: "" },
        }))
      }
      if (tasks.length === 0) return;
      Actions.queueTasks(tasks);
    })
  }

  notifySuccess = (sObject) => {
    SalesforceActions.syncbackSuccess({
      objectId: sObject.id,
      objectType: sObject.type,
      contextData: this.contextData,
      formPostData: this.formPostData,
      relatedObjectsData: this.relatedObjectsData,
    })
  }

  handleError = (apiError = {}) => {
    const name = this.formPostData.Name || this.formPostData.Email
    SalesforceActions.reportError(apiError, {
      sObjectId: this.objectId,
      sObjectType: this.objectType,
      sObjectName: name,
      contextData: this.contextData,
      formPostData: this.formPostData,
      relatedObjectsData: this.relatedObjectsData,
    });
    SalesforceActions.syncbackFailed({
      objectType: this.objectType,
      contextData: this.contextData,
      error: apiError,
    });
    return Promise.resolve([Task.Status.Failed, apiError])
  }
}
