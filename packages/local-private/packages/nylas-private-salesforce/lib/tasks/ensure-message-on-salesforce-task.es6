import _ from 'underscore'
import {
  Task,
  Utils,
  Message,
  Actions,
  DatabaseStore,
  SyncbackMetadataTask,
} from 'nylas-exports'
import moment from 'moment'

import {PLUGIN_ID} from '../salesforce-constants'
import SalesforceAPI from '../salesforce-api'
import * as mdHelpers from '../metadata-helpers'
import SalesforceObject from '../models/salesforce-object'
import SalesforceActions from '../salesforce-actions'

export default class EnsureMessageOnSalesforceTask extends Task {
  constructor({messageId, sObjectId, sObjectType} = {}) {
    super()
    this.messageId = messageId;
    this.sObjectId = sObjectId;
    this.sObjectType = sObjectType;
    this.isCanceled = false;
  }

  isSameAndOlderTask(other) {
    return other instanceof EnsureMessageOnSalesforceTask &&
      other.messageId === this.messageId &&
      other.sequentialId < this.sequentialId;
  }

  isComplementTask(other) {
    return other.constructor.name === "DestroyMessageOnSalesforceTask" &&
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
    return this._checkIfFullySynced()
    .then((fullySynced) => {
      if (fullySynced) {
        return DatabaseStore.find(Message, this.messageId)
        .then(this._unmarkPendingStatus)
        .then(() => Task.Status.Success)
      }

      if (this.isCanceled) return Promise.resolve(Task.Status.Success);

      return DatabaseStore.find(Message, this.messageId)
      .include(Message.attributes.body)
      .then(this._prepareMessageBody)
      .then(this._createNewActivityObjects)
      .thenReturn(Task.Status.Success)
    })
  }

  cancel() {
    this.isCanceled = true;
  }

  _markPendingStatus = (message) => {
    const metadata = Utils.deepClone(message.metadataForPluginId(PLUGIN_ID) || {});
    metadata.pendingSync = true
    message.applyPluginMetadata(PLUGIN_ID, metadata);
    return DatabaseStore.inTransaction(t => t.persistModel(message))
  }

  _unmarkPendingStatus = (message) => {
    const metadata = Utils.deepClone(message.metadataForPluginId(PLUGIN_ID) || {});
    metadata.pendingSync = false
    message.applyPluginMetadata(PLUGIN_ID, metadata);
    return DatabaseStore.inTransaction(t => t.persistModel(message))
  }

  // We do an initial check here to see if we need to fully load the
  // message's body and go through the effort of creating objects.
  _checkIfFullySynced() {
    return DatabaseStore.find(Message, this.messageId).then((message) => {
      return this._typesToClone(message).length === 0
    })
  }

  _typesToClone(message) {
    const clonedAs = _.values(mdHelpers.getClonedAsForSObject(message, {
      id: this.sObjectId}));

    return _.difference(["Task", "EmailMessage"], _.pluck(clonedAs, "type"))
  }

  _prepareMessageBody = (message) => {
    if (this.isCanceled) return Promise.resolve();
    const mDom = message.computeDOMWithoutQuotes();
    const bodies = {
      plainTextUnquoted: message.cleanPlainTextBody(mDom.body.innerText),
      htmlUnquoted: mDom.body.innerHTML,
    }
    return Promise.resolve({message, bodies})
  }

  _createNewActivityObjects = ({message, bodies}) => {
    if (this.isCanceled) return Promise.resolve();

    const clonedAs = mdHelpers.getClonedAsForSObject(message, {id: this.sObjectId});
    const clonedAsTypes = _.pluck(_.values(clonedAs), "type")

    return Promise.resolve()
    .then(() => {
      if (clonedAsTypes.includes("EmailMessage")) { return Promise.resolve() }
      return this._newEmailMessage({message, bodies})
      .then((sfCreatedObj = {}) => {
        mdHelpers.addClonedSObject(message, {id: this.sObjectId}, {
          id: sfCreatedObj.id,
          type: "EmailMessage",
          relatedToId: this.sObjectId,
        })
        return sfCreatedObj.id
      })
    })
    .catch((err) => {
      // If we can't create the EmailMessage object, attempt to
      // manually create a Task instead.
      //
      // This happens fairly frequently because the EmailMessage
      // object type has fairly strict limits on the size of the HTML
      // body you can upload to Salesforce.
      //
      // We store the error if it's permanent so we don't keep retrying
      // the same error

      if (clonedAsTypes.includes("Task")) { return Promise.resolve() }

      return this._newTask({message, bodies})
      .then((sfCreatedObj) => {
        mdHelpers.addClonedSObject(message, {id: this.sObjectId}, {
          id: sfCreatedObj.id,
          type: "Task",
          relatedToId: this.sObjectId,
        })
      }).then(() => {
        // Be sure to re-throw the error
        throw err
      })
    })
    .then((newEmailMessageId) => {
      if (clonedAsTypes.includes("Task")) { return Promise.resolve() }

      // Once an EmailMessage object is created, it'll automatically
      // also create a corresponding Task object.
      return SalesforceAPI.makeRequest({
        path: `/sobjects/EmailMessage/${newEmailMessageId}`,
      })
    })
    .then((rawEmailMessage) => {
      if (clonedAsTypes.includes("Task")) { return Promise.resolve() }
      // Load the raw Task.
      return SalesforceAPI.makeRequest({
        path: `/sobjects/Task/${rawEmailMessage.ActivityId}`,
      })
    })
    .then((rawTask) => {
      if (clonedAsTypes.includes("Task")) { return Promise.resolve() }
      return this._updateTask({rawTask, message, bodies})
      .then(() => {
        mdHelpers.addClonedSObject(message, {id: this.sObjectId}, {
          id: rawTask.Id,
          type: "Task",
          relatedToId: this.sObjectId,
        })
      })
    })
    .finally(() => { this._syncbackMetadata(message) })
  }

  _syncbackMetadata = (message) => {
    return this._unmarkPendingStatus(message).then(() => {
      const task = new SyncbackMetadataTask(message.clientId, "Message", PLUGIN_ID);
      Actions.queueTask(task);
    })
  }

  _updateTask({rawTask, message}) {
    return DatabaseStore.findBy(SalesforceObject,
        {type: "Contact", identifier: message.fromContact().email})
    .then((contact) => {
      const updates = {
        Status: "Completed",
      }
      if (contact) { updates.WhoId = contact.id }
      return SalesforceAPI.makeRequest({
        method: "PATCH",
        path: `/sobjects/Task/${rawTask.Id}`,
        body: updates,
      }).catch((apiError) => {
        // These shouldn't fail. If they do we need to look on Sentry.
        // Unfortunately there's no user feedback yet, so report and
        // re-throw so the task fails.
        SalesforceActions.reportError(apiError, {rawPostData: updates})
        throw apiError
      });
    })
  }

  // https://na16.salesforce.com/services/data/v37.0/query?q=SELECT id, subject FROM EmailMessage WHERE sObjectIdToSync='006j000000T2I08AAF'
  // Example Task:
  // https://na16.salesforce.com/services/data/v37.0/sobjects/Task/00Tj000001M3XtrEAF
  _newTask({message, bodies}) {
    const to = message.to.map((p) => p.email)
    const cc = message.cc.map((p) => p.email)
    const bcc = message.bcc.map((p) => p.email)
    const fileNames = message.files.map((f) => f.filename)
    const task = {
      Subject: `Email: ${message.subject}`,
      Description: `Date: ${moment(message.date).format('MMMM Do YYYY, h:mm:ss a')}\nAdditional To: ${to.join(", ")}\nCC: ${cc.join(", ")}\nBCC: ${bcc.join(", ")}\nAttachment: ${fileNames.join(", ")}\n\nSubject: ${message.subject}\nBody:\n${bodies.plainTextUnquoted}`,
      WhatId: this.sObjectId,
      TaskSubtype: "Email",
      ActivityDate: moment(message.date).format("YYYY-MM-DD"),
      Status: "Completed",
      Priority: "Normal",
    }

    return DatabaseStore.findBy(SalesforceObject,
        {type: "Contact", identifier: message.fromContact().email})
    .then((contact) => {
      if (contact) { task.WhoId = contact.id }
      return SalesforceAPI.makeRequest({
        method: "POST",
        path: `/sobjects/Task/`,
        body: task,
      }).catch((apiError) => {
        // These shouldn't fail. If they do we need to look on Sentry.
        // Unfortunately there's no user feedback yet, so report and
        // re-throw so the task fails.
        SalesforceActions.reportError(apiError, {rawPostData: task})
        throw apiError
      });
    })
  }

  // Note this invisible Task:
  // https://na16.salesforce.com/services/data/v37.0/sobjects/Task/00Tj000001LLhZbEAL
  // Is a duplicate of this EmailMessage:
  // Example EmailMessage:
  // https://na16.salesforce.com/services/data/v37.0/sobjects/EmailMessage/02sj0000006tyw6AAA
  _newEmailMessage({message, bodies}) {
    const emailMessage = {
      TextBody: bodies.plainTextUnquoted,
      HtmlBody: bodies.htmlUnquoted,
      Headers: null,
      Subject: message.subject,
      FromName: message.fromContact().name,
      FromAddress: message.fromContact().email,
      ToAddress: message.to.map((p) => p.email).join(";"),
      CcAddress: message.cc.map((p) => p.email).join(";"),
      BccAddress: message.bcc.map((p) => p.email).join(";"),
      MessageDate: moment(message.date).format(),
      ReplyToEmailMessageId: null,
      RelatedToId: this.sObjectId,
    }
    return SalesforceAPI.makeRequest({
      method: "POST",
      path: `/sobjects/EmailMessage/`,
      body: emailMessage,
    }).catch((apiError) => {
      // These shouldn't fail. If they do we need to look on Sentry.
      // Unfortunately there's no user feedback yet, so report and
      // re-throw so the task fails.
      SalesforceActions.reportError(apiError, {rawPostData: emailMessage})
      throw apiError
    });
  }
}
