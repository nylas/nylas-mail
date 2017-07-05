/* eslint global-require: 0 */
import AccountStore from '../stores/account-store';
import Task from './task';

const OPEN_TRACKING_ID = NylasEnv.packages.pluginIdFor('open-tracking')
const LINK_TRACKING_ID = NylasEnv.packages.pluginIdFor('link-tracking')


export default class SendDraftTask extends Task {

  constructor(draft, {playSound = true, emitError = true, allowMultiSend = true} = {}) {
    super();
    this.draft = draft;
    this.accountId = (draft || {}).accountId;
    this.headerMessageId = (draft || {}).headerMessageId;

    this.emitError = emitError
    this.playSound = playSound
    this.allowMultiSend = allowMultiSend
  }

  label() {
    return "Sending message";
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
    return Promise.resolve();
  }

  _trackingPluginsInUse() {
    const pluginsAvailable = (OPEN_TRACKING_ID && LINK_TRACKING_ID);
    if (!pluginsAvailable) {
      return false;
    }
    return (!!this.draft.metadataForPluginId(OPEN_TRACKING_ID) || !!this.draft.metadataForPluginId(LINK_TRACKING_ID)) || false;
  }

  _createMessageFromResponse = (responseJSON) => {
    const {failedRecipients, message} = responseJSON
    if (failedRecipients && failedRecipients.length > 0) {
      const errorMessage = `We had trouble sending this message to all recipients. ${failedRecipients} may not have received this email.`;
      NylasEnv.showErrorDialog(errorMessage, {showInMainWindow: true});
    }
    if (!message || !message.id || !message.account_id) {
      const errorMessage = `Your message successfully sent; however, we had trouble saving your message, "${message.subject}", to your Sent folder.`;
      if (!message) {
        throw new Error(`${errorMessage}\n\nError: Did not return message`)
      }
      if (!message.id) {
        throw new Error(`${errorMessage}\n\nError: Returned a message without id`)
      }
      if (!message.accountId) {
        throw new Error(`${errorMessage}\n\nError: Returned a message without accountId`)
      }
    }

    this.message = new Message().fromJSON(message);
    this.message.id = this.draft.id;
    this.message.body = this.draft.body;
    this.message.draft = false;
    this.message.clonePluginMetadataFrom(this.draft);

    return DatabaseStore.inTransaction((t) =>
      this.refreshDraftReference().then(() => {
        return t.persistModel(this.message);
      })
    );
  }

  onSuccess = () => {
    Actions.recordUserEvent("Draft Sent")
    Actions.draftDeliverySucceeded({message: this.message, messageId: this.message.id, headerMessageId: this.draft.headerMessageId});

    // Play the sending sound
    if (this.playSound && NylasEnv.config.get("core.sending.sounds")) {
      SoundRegistry.playSound('send');
    }
    return Promise.resolve(Task.Status.Success);
  }

  onError = (err) => {
    let message = err.message;

    // TODO Handle errors in a cleaner way
    if (err instanceof APIError) {
      const errorMessage = (err.body && err.body.message) || ''
      message = `Sorry, this message could not be sent, please try again.`;
      message += `\n\nReason: ${err.message}`
      if (errorMessage.includes('unable to reach your SMTP server')) {
        message = `Sorry, this message could not be sent. There was a network error, please make sure you are online.`
      }
      if (errorMessage.includes('Incorrect SMTP username or password') ||
          errorMessage.includes('SMTP protocol error') ||
          errorMessage.includes('unable to look up your SMTP host')) {
        Actions.updateAccount(this.draft.accountId, {syncState: Account.SYNC_STATE_AUTH_FAILED})
        message = `Sorry, this message could not be sent due to an authentication error. Please re-authenticate your account and try again.`
      }
      if (err.statusCode === 402) {
        if (errorMessage.includes('at least one recipient')) {
          message = `This message could not be delivered to at least one recipient. (Note: other recipients may have received this message - you should check Sent Mail before re-sending this message.)`;
        } else {
          message = `Sorry, this message could not be sent because it was rejected by your mail provider. (${errorMessage})`;
          if (err.body.server_error) {
            message += `\n\n${err.body.server_error}`;
          }
        }
      }
    }

    if (this.emitError) {
      if (err instanceof RequestEnsureOnceError) {
        Actions.draftDeliveryFailed({
          threadId: this.draft.threadId,
          headerMessageId: this.draft.headerMessageId,
          errorMessage: `WARNING: Your message MIGHT have sent. We encountered a network problem while the send was in progress. Please wait a few minutes then check your sent folder and try again if necessary.`,
          errorDetail: `Please email support@nylas.com if you see this error message.`,
        });
      } else {
        Actions.draftDeliveryFailed({
          threadId: this.draft.threadId,
          headerMessageId: this.draft.headerMessageId,
          errorMessage: message,
          errorDetail: err.message + (err.error ? err.error.stack : '') + err.stack,
        });
      }
    }
    Actions.recordUserEvent("Draft Sending Errored", {
      error: err.message,
      errorClass: err.constructor.name,
    })
    err.message = `Send failed (client): ${err.message}`
    NylasEnv.reportError(err);

    return Promise.resolve([Task.Status.Failed, err]);
  }

}
