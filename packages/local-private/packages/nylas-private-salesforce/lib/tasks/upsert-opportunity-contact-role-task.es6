import _ from 'underscore'
import {Task, Utils, DatabaseStore} from 'nylas-exports'
import SalesforceAPI from '../salesforce-api'
import SalesforceObject from '../models/salesforce-object'
import * as dataHelpers from '../salesforce-object-helpers'


class UpsertOpportunityContactRoleTask extends Task {
  constructor({opportunityId, emails} = {}) {
    super()
    this.opportunityId = opportunityId
    this.emails = emails
  }

  isSameAndOlderTask(other) {
    return other instanceof UpsertOpportunityContactRoleTask &&
      other.opportunityId === this.opportunityId &&
      Utils.isEqual(other.emails, this.emails) &&
      other.sequentialId < this.sequentialId;
  }

  shouldDequeueOtherTask(other) {
    return this.isSameAndOlderTask(other)
  }

  isDependentOnTask(other) {
    return this.isSameAndOlderTask(other)
  }

  performRemote() {
    return Promise.resolve()
    .then(this._fetchAndSaveContactsFromEmails)
    .then(this._fetchAndSaveRolesFromContacts)
    .then(this._calculateMissingRoles)
    .then(this._submitMissingRoles)
    .then(() => Task.Status.Success)
  }

  _identifier(contact) {
    return `${this.opportunityId}-${contact.id}`
  }

  _fetchAndSaveContactsFromEmails = () => {
    // console.log("---> Finding Contacts from emails")
    return DatabaseStore.findAll(SalesforceObject, {
      type: "Contact",
      identifier: this.emails,
    }).then((sfContactModels = []) => {
      const toFetch = _.difference(this.emails, _.pluck(sfContactModels, "identifier"));
      return Promise.map(toFetch, (emailToFetch) => {
        return dataHelpers.loadBasicObjectsByField({
          objectType: "Contact",
          where: {Email: emailToFetch},
        })
        .then(dataHelpers.upsertBasicObjects)
      }).then((savedContactsFromAPI = []) => {
        return sfContactModels.concat(_.compact(_.flatten(savedContactsFromAPI)))
      })
    })
  }

  _fetchAndSaveRolesFromContacts = (sfContactModels = []) => {
    // console.log("---> Found Contats", sfContactModels)
    const identifiers = sfContactModels.map((sfContact) => {
      return this._identifier(sfContact);
    })
    // console.log("---> Finding OpportunityContactRoles from Contats")
    return DatabaseStore.findAll(SalesforceObject, {
      type: "OpportunityContactRole",
      identifier: identifiers,
    }).then((roles = []) => {
      const toFetch = _.difference(identifiers, _.pluck(roles, "identifier"));
      return Promise.map(toFetch, (identifier) => {
        return dataHelpers.loadBasicObjectsByField({
          objectType: "OpportunityContactRole",
          fields: ["Id", "OpportunityId", "ContactId"],
          where: {
            OpportunityId: this.opportunityId,
            ContactId: identifier.split("-")[1],
          },
        })
        .then(dataHelpers.upsertBasicObjects)
      })
      .then((savedOpportunityContactRoles = []) => {
        return roles.concat(_.compact(_.flatten(savedOpportunityContactRoles)))
      })
      .then((sfOpportunityContactRoles = []) => {
        return {sfContactModels, sfOpportunityContactRoles}
      })
    })
  }

  _calculateMissingRoles = ({sfContactModels, sfOpportunityContactRoles}) => {
    // console.log("---> Found OpportunityContatRoles", sfOpportunityContactRoles)
    const contactIds = sfContactModels.map((sfContact) => {
      return this._identifier(sfContact);
    })
    const roleIds = _.pluck(sfOpportunityContactRoles, "identifier");
    return _.difference(contactIds, roleIds).map((ident) => {
      return ident.split("-")[1]
    })
  }

  _submitMissingRoles = (missingContactIds = []) => {
    // console.log(`---> ${missingContactIds.length} missing Roles`, missingContactIds)
    if (missingContactIds.length === 0) return Promise.resolve();
    return Promise.each(missingContactIds, (contactId) => {
      return SalesforceAPI.makeRequest({
        path: `/sobjects/OpportunityContactRole`,
        method: "POST",
        body: {
          OpportunityId: this.opportunityId,
          ContactId: contactId,
        },
      }).then((sfCreatedObj) => {
        return dataHelpers.requestFullObjectFromAPI({
          objectType: "OpportunityContactRole",
          objectId: sfCreatedObj.id,
        })
      })
    }).then(() => {
      // console.log("Saved OpportunityContactRoles")
    })
  }
}

export default UpsertOpportunityContactRoleTask
