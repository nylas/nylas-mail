/* eslint global-require: 0 */
import {RegExpUtils} from 'nylas-exports';
import Task from './task';
import Actions from '../actions';
import Message from '../models/message';
import NylasAPI from '../nylas-api';
import {APIError} from '../errors';
import SoundRegistry from '../../sound-registry';
import DatabaseStore from '../stores/database-store';
import AccountStore from '../stores/account-store';
import BaseDraftTask from './base-draft-task';
import MultiSendToIndividualTask from './multi-send-to-individual-task';
import MultiSendSessionCloseTask from './multi-send-session-close-task';
import SyncbackMetadataTask from './syncback-metadata-task';
import NotifyPluginsOfSendTask from './notify-plugins-of-send-task';


// TODO
// Refactor this to consolidate error handling across all Sending tasks
export default class SendDraftTask extends BaseDraftTask {

  constructor(draftClientId, {playSound = true, emitError = true, allowMultiSend = true} = {}) {
    super(draftClientId);
    this.draft = null;
    this.message = null;
    this.emitError = emitError
    this.playSound = playSound
    this.allowMultiSend = allowMultiSend
  }

  label() {
    return "Sending message...";
  }

  performRemote() {
    return this.refreshDraftReference()
    .then(this.assertDraftValidity)
    .then(this.sendMessage)
    .then(this.updatePluginMetadata)
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

  usingMultiSend = () => {
    if (!this.allowMultiSend) {
      return false;
    }

    // Sending individual bodies for too many participants can cause us
    // to hit the smtp rate limit.
    if (this.draft.participants({includeFrom: false, includeBcc: true}).length > 10) {
      return false;
    }

    const openTrackingId = NylasEnv.packages.pluginIdFor('open-tracking')
    const linkTrackingId = NylasEnv.packages.pluginIdFor('link-tracking')

    const pluginsAvailable = (openTrackingId && linkTrackingId);
    if (!pluginsAvailable) {
      return false;
    }
    const pluginsInUse = (this.draft.metadataForPluginId(openTrackingId) || this.draft.metadataForPluginId(linkTrackingId));
    const providerCompatible = (AccountStore.accountForId(this.draft.accountId).provider !== "eas");
    return pluginsInUse && providerCompatible;
  }

  sendMessage = () => {
    return this.usingMultiSend() ? this.sendWithMultipleBodies() : this.sendWithSingleBody();
  }

  sendWithMultipleBodies = () => {
    const draft = this.draft.clone();
    draft.body = this.stripTrackingFromBody(draft.body);

    return NylasAPI.makeRequest({
      path: "/send-multiple",
      accountId: this.draft.accountId,
      method: 'POST',
      body: draft.toJSON(),
      timeout: 1000 * 60 * 5, // We cannot hang up a send - won't know if it sent
      returnsModel: false,
    })
    .then((responseJSON) => {
      return this.createMessageFromResponse(responseJSON);
    })
    .then(() => {
      const recipients = this.message.participants({includeFrom: false, includeBcc: true})
      recipients.forEach((recipient) => {
        const t1 = new MultiSendToIndividualTask({
          message: this.message,
          recipient: recipient,
        });
        Actions.queueTask(t1);
      });
      const t2 = new MultiSendSessionCloseTask({
        message: this.message,
        draft: draft,
      });
      Actions.queueTask(t2);
    })
    .catch((err) => {
      return this.onSendError(err, this.sendWithMultipleBodies);
    })
  }

  // This function returns a promise that resolves to the draft when the draft has
  // been sent successfully.
  sendWithSingleBody = () => {
    return NylasAPI.makeRequest({
      path: "/send",
      accountId: this.draft.accountId,
      method: 'POST',
      body: this.draft.toJSON(),
      timeout: 1000 * 60 * 5, // We cannot hang up a send - won't know if it sent
      returnsModel: false,
    })
    .then((responseJSON) => {
      return this.createMessageFromResponse(responseJSON)
    })
    .catch((err) => {
      return this.onSendError(err, this.sendWithSingleBody);
    })
  }

  updatePluginMetadata = () => {
    this.message.pluginMetadata.forEach((m) => {
      const t1 = new SyncbackMetadataTask(this.message.clientId,
          this.message.constructor.name, m.pluginId);
      Actions.queueTask(t1);
    });

    if (this.message.pluginMetadata.length > 0) {
      const t2 = new NotifyPluginsOfSendTask({
        accountId: this.message.accountId,
        messageId: this.message.id,
        messageClientId: this.message.clientId,
      });
      Actions.queueTask(t2);
    }

    return Promise.resolve();
  }

  createMessageFromResponse = (responseJSON) => {
    this.message = new Message().fromJSON(responseJSON);
    this.message.clientId = this.draft.clientId;
    this.message.body = this.draft.body;
    this.message.draft = false;
    this.message.clonePluginMetadataFrom(this.draft);

    return DatabaseStore.inTransaction((t) =>
      this.refreshDraftReference().then(() => {
        return t.persistModel(this.message);
      })
    );
  }

  stripTrackingFromBody(text) {
    let body = text.replace(/<img class="n1-open"[^<]+src="([a-zA-Z0-9-_:\/.]*)">/g, () => {
      return "";
    });
    body = body.replace(RegExpUtils.urlLinkTagRegex(), (match, prefix, url, suffix, content, closingTag) => {
      const param = url.split("?")[1];
      if (param) {
        const link = decodeURIComponent(param.split("=")[1]);
        return `${prefix}${link}${suffix}${content}${closingTag}`;
      }
      return match;
    });
    return body;
  }

  onSuccess = () => {
    // TODO: This code is duplicated into the MultiSendSessionCloseTask!
    // We should create a Task that always runs when send is complete.
    if (!this.usingMultiSend()) {
      Actions.recordUserEvent("Draft Sent")
      Actions.sendDraftSuccess({message: this.message, messageClientId: this.message.clientId, draftClientId: this.draft.clientId});
      NylasAPI.makeDraftDeletionRequest(this.draft);

      // Play the sending sound
      if (this.playSound && NylasEnv.config.get("core.sending.sounds")) {
        SoundRegistry.playSound('send');
      }
    }
    return Promise.resolve(Task.Status.Success);
  }

  onSendError = (err, retrySend) => {
    let shouldRetry = false;
    // If the message you're "replying to" has been deleted
    if (err.message && err.message.indexOf('Invalid message public id') === 0) {
      this.draft.replyToMessageId = null;
      shouldRetry = true
    }

    // If the thread has been deleted
    if (err.message && err.message.indexOf('Invalid thread') === 0) {
      this.draft.threadId = null;
      this.draft.replyToMessageId = null;
      shouldRetry = true
    }

    Actions.recordUserEvent("Draft Sending Errored", {
      error: err.message,
      shouldRetry: shouldRetry,
    })

    if (shouldRetry) {
      return retrySend()
    }

    return Promise.reject(err);
  }

  onError = (err) => {
    if (err instanceof BaseDraftTask.DraftNotFoundError) {
      return Promise.resolve(Task.Status.Continue);
    }

    let message = err.message;

    if (err instanceof APIError) {
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

    if (this.emitError) {
      Actions.sendDraftFailed({
        threadId: this.draft.threadId,
        draftClientId: this.draft.clientId,
        errorMessage: message,
      });
    }
    NylasEnv.reportError(err);

    return Promise.resolve([Task.Status.Failed, err]);
  }
}
