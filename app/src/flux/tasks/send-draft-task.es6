/* eslint global-require: 0 */
import AccountStore from '../stores/account-store';
import Task from './task';
import Actions from '../actions';
import SoundRegistry from '../../registries/sound-registry';
import Attributes from '../attributes';
import Message from '../models/message';

const OPEN_TRACKING_ID = NylasEnv.packages.pluginIdFor('open-tracking')
const LINK_TRACKING_ID = NylasEnv.packages.pluginIdFor('link-tracking')


export default class SendDraftTask extends Task {

  static attributes = Object.assign({}, Task.attributes, {
    draft: Attributes.Object({
      modelKey: 'draft',
      itemClass: Message,
    }),
    headerMessageId: Attributes.String({
      modelKey: 'headerMessageId',
    }),
    emitError: Attributes.Boolean({
      modelKey: 'emitError',
    }),
    playSound: Attributes.Boolean({
      modelKey: 'playSound',
    }),
    allowMultiSend: Attributes.Boolean({
      modelKey: 'allowMultiSend',
    }),
    perRecipientBodies: Attributes.Collection({
      modelKey: 'perRecipientBodies',
    }),
  });

  constructor({draft, playSound = true, emitError = true, allowMultiSend = true, ...rest} = {}) {
    super(rest);
    this.accountId = (draft || {}).accountId;
    this.headerMessageId = (draft || {}).headerMessageId;
    this.emitError = emitError
    this.playSound = playSound
    this.allowMultiSend = allowMultiSend

    if (draft) {
      // const pluginsAvailable = (OPEN_TRACKING_ID && LINK_TRACKING_ID);
      // const pluginsInUse = pluginsAvailable && (!!this.draft.metadataForPluginId(OPEN_TRACKING_ID) || !!this.draft.metadataForPluginId(LINK_TRACKING_ID));
      // if (pluginsInUse) {
      this.perRecipientBodies = {
        self: draft.body,
      };
      // perform transformations here
      const ps = draft.participants({includeFrom: false, includeBcc: true});
      ps.forEach((p) => {
        this.perRecipientBodies[p.email] = draft.body + p.email;
      })
      // }
    }
  }

  label() {
    return "Sending message";
  }

  validate() {
    const account = AccountStore.accountForEmail(this.draft.from[0].email);

    if (!this.draft.from[0]) {
      throw new Error("SendDraftTask - you must populate `from` before sending.");
    }
    if (!account) {
      throw new Error("SendDraftTask - you can only send drafts from a configured account.");
    }
    if (this.draft.accountId !== account.id) {
      throw new Error("The from address has changed since you started sending this draft. Double-check the draft and click 'Send' again.");
    }
  }

  onSuccess() {
    Actions.recordUserEvent("Draft Sent")
    Actions.draftDeliverySucceeded({headerMessageId: this.draft.headerMessageId});

    // Play the sending sound
    if (this.playSound && NylasEnv.config.get("core.sending.sounds")) {
      SoundRegistry.playSound('send');
    }
  }

  onError({key, debuginfo}) {
    let message = key;
    if (key === 'no-sent-folder') {
      message = "We couldn't find a Sent folder in your account.";
    }

    if (this.emitError) {
      Actions.draftDeliveryFailed({
        threadId: this.draft.threadId,
        headerMessageId: this.draft.headerMessageId,
        errorMessage: message,
        errorDetail: debuginfo,
      });
    }
    Actions.recordUserEvent("Draft Sending Errored", {
      error: message,
      key: key,
    })
  }

}
