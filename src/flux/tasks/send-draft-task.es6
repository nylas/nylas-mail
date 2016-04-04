import Task from './task';
import Actions from '../actions';
import Message from '../models/message';
import NylasAPI from '../nylas-api';
import {APIError} from '../errors';
import SoundRegistry from '../../sound-registry';
import DatabaseStore from '../stores/database-store';
import AccountStore from '../stores/account-store';
import BaseDraftTask from './base-draft-task';
import SyncbackMetadataTask from './syncback-metadata-task';

export default class SendDraftTask extends BaseDraftTask {

  constructor(draftClientId) {
    super(draftClientId);
    this.uploaded = [];
    this.draft = null;
    this.message = null;
  }

  label() {
    return "Sending message...";
  }

  performRemote() {
    return this.refreshDraftReference()
    .then(this.assertDraftValidity)
    .then(this.sendMessage)
    .then((responseJSON) => {
      this.message = new Message().fromJSON(responseJSON)
      this.message.clientId = this.draft.clientId
      this.message.draft = false
      this.message.clonePluginMetadataFrom(this.draft)

      return DatabaseStore.inTransaction((t) =>
        this.refreshDraftReference().then(() =>
          t.persistModel(this.message)
        )
      );
    })
    .then(this.onSuccess)
    .catch(this.onError);
  }

  assertDraftValidity = () => {
    if (!this.draft.from[0]) {
      return Promise.reject(new Error("SendDraftTask - you must populate `from` before sending."));
    }

    const account = AccountStore.accountForEmail(this.draft.from[0].email);
    if (!account) {
      return Promise.reject(new Error("SendDraftTask - you can only send drafts from a configured account."));
    }
    if (this.draft.accountId !== account.id) {
      return Promise.reject(new Error("The from address has changed since you started sending this draft. Double-check the draft and click 'Send' again."));
    }
    if (this.draft.uploads && (this.draft.uploads.length > 0)) {
      return Promise.reject(new Error("Files have been added since you started sending this draft. Double-check the draft and click 'Send' again.."));
    }
    return Promise.resolve();
  }

  // This function returns a promise that resolves to the draft when the draft has
  // been sent successfully.
  sendMessage = () => {
    return NylasAPI.makeRequest({
      path: "/send",
      accountId: this.draft.accountId,
      method: 'POST',
      body: this.draft.toJSON(),
      timeout: 1000 * 60 * 5, // We cannot hang up a send - won't know if it sent
      returnsModel: false,
    })
    .catch((err) => {
      // If the message you're "replying to" were deleted
      if (err.message && err.message.indexOf('Invalid message public id') === 0) {
        this.draft.replyToMessageId = null
        return this.sendMessage()
      }

      // If the thread was deleted
      if (err.message && err.message.indexOf('Invalid thread') === 0) {
        this.draft.threadId = null;
        this.draft.replyToMessageId = null;
        return this.sendMessage();
      }

      return Promise.reject(err)
    });
  }

  onSuccess = () => {
    // Queue a task to save metadata on the message
    this.message.pluginMetadata.forEach((m) => {
      const task = new SyncbackMetadataTask(this.message.clientId, this.message.constructor.name, m.pluginId);
      Actions.queueTask(task);
    });

    Actions.sendDraftSuccess({message: this.message, messageClientId: this.message.clientId, draftClientId: this.draftClientId});
    NylasAPI.makeDraftDeletionRequest(this.draft);

    // Play the sending sound
    if (NylasEnv.config.get("core.sending.sounds")) {
      SoundRegistry.playSound('send');
    }

    return Promise.resolve(Task.Status.Success);
  }

  onError = (err) => {
    if (err instanceof BaseDraftTask.DraftNotFoundError) {
      return Promise.resolve(Task.Status.Continue);
    }

    let message = err.message;

    if (err instanceof APIError) {
      if (!NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
        return Promise.resolve(Task.Status.Retry);
      }

      message = `Sorry, this message could not be sent. Please try again, and make sure your message is addressed correctly and is not too large.`;
      if (err.statusCode === 402 && err.body.message) {
        if (err.body.message.indexOf('at least one recipient') !== -1) {
          message = `This message could not be delivered to at least one recipient. (Note: other recipients may have received this message - you should check Sent Mail before re-sending this message.)`;
        } else {
          message = `Sorry, this message could not be sent because it was rejected by your mail provider. (${err.body.message})`;
          if (err.body.server_error) {
            message += `\n\n${err.body.server_error}`;
          }
        }
      }
    }

    Actions.draftSendingFailed({
      threadId: this.draft.threadId,
      draftClientId: this.draft.clientId,
      errorMessage: message,
    });
    NylasEnv.reportError(err);

    return Promise.resolve([Task.Status.Failed, err]);
  }
}
