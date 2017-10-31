/* eslint global-require: 0 */
import url from 'url';
import AccountStore from '../stores/account-store';
import Task from './task';
import Actions from '../actions';
import Attributes from '../attributes';
import Message from '../models/message';
import SoundRegistry from '../../registries/sound-registry';
import { LocalizedErrorStrings } from '../../mailsync-process';

export default class SendDraftTask extends Task {
  static attributes = Object.assign({}, Task.attributes, {
    draft: Attributes.Object({
      modelKey: 'draft',
      itemClass: Message,
    }),
    headerMessageId: Attributes.String({
      modelKey: 'headerMessageId',
    }),
    perRecipientBodies: Attributes.Object({
      modelKey: 'perRecipientBodies',
    }),

    silent: Attributes.Boolean({
      modelKey: 'silent',
    }),
  });

  get accountId() {
    return this.draft.accountId;
  }

  set accountId(a) {
    // no-op
  }

  get headerMessageId() {
    return this.draft.headerMessageId;
  }

  set headerMessageId(h) {
    // no-op
  }

  constructor(...args) {
    super(...args);

    if (this.draft) {
      const OPEN_TRACKING_ID = AppEnv.packages.pluginIdFor('open-tracking');
      const LINK_TRACKING_ID = AppEnv.packages.pluginIdFor('link-tracking');

      const pluginsAvailable = OPEN_TRACKING_ID && LINK_TRACKING_ID;
      const pluginsInUse =
        pluginsAvailable &&
        (!!this.draft.metadataForPluginId(OPEN_TRACKING_ID) ||
          !!this.draft.metadataForPluginId(LINK_TRACKING_ID));
      if (pluginsInUse) {
        const bodies = {
          self: this.draft.body,
        };
        this.draft.participants({ includeFrom: false, includeBcc: true }).forEach(recipient => {
          bodies[recipient.email] = this.personalizeBodyForRecipient(this.draft.body, recipient);
        });
        this.perRecipientBodies = bodies;
      }
    }
  }

  label() {
    return this.silent ? null : 'Sending message';
  }

  validate() {
    const account = AccountStore.accountForEmail(this.draft.from[0].email);

    if (!this.draft.from[0]) {
      throw new Error('SendDraftTask - you must populate `from` before sending.');
    }
    if (!account) {
      throw new Error('SendDraftTask - you can only send drafts from a configured account.');
    }
    if (this.draft.accountId !== account.id) {
      throw new Error(
        "The from address has changed since you started sending this draft. Double-check the draft and click 'Send' again."
      );
    }
  }

  onSuccess() {
    Actions.recordUserEvent('Draft Sent');
    Actions.draftDeliverySucceeded({
      headerMessageId: this.draft.headerMessageId,
      accountId: this.draft.accountId,
    });

    // Play the sending sound
    if (AppEnv.config.get('core.sending.sounds') && !this.silent) {
      SoundRegistry.playSound('send');
    }
  }

  onError({ key, debuginfo }) {
    let errorMessage = null;
    let errorDetail = null;

    if (key === 'no-sent-folder') {
      errorMessage = "We couldn't find a Sent folder in your account.";
      errorDetail =
        'In order to send mail through Mailspring, your email account must have a Sent Mail folder.';
    } else if (key === 'no-trash-folder') {
      errorMessage = "We couldn't find a Sent folder in your account.";
      errorDetail =
        'In order to send mail through Mailspring, your email account must have a Trash folder.';
    } else if (key === 'send-partially-failed') {
      const [smtpError, emails] = debuginfo.split(':::');
      errorMessage =
        "We were unable to deliver this message to some recipients. Click 'See Details' for more information.";
      errorDetail = `We encountered an SMTP Gateway error that prevented this message from being delivered to all recipients. The message was only sent successfully to these recipients:\n${emails}\n\nError: ${LocalizedErrorStrings[
        smtpError
      ]}`;
    } else if (key === 'send-failed') {
      errorMessage = `We were unable to deliver this message. ${LocalizedErrorStrings[debuginfo]}`;
      errorDetail = `We encountered an SMTP error that prevented this message from being delivered:\n\n${LocalizedErrorStrings[
        debuginfo
      ]}`;
    } else {
      errorMessage = 'We were unable to deliver this message.';
      errorDetail = `An unknown error occurred: ${JSON.stringify({ key, debuginfo })}`;
    }

    Actions.draftDeliveryFailed({
      threadId: this.draft.threadId,
      headerMessageId: this.draft.headerMessageId,
      errorMessage,
      errorDetail,
    });
    Actions.recordUserEvent('Draft Sending Errored', {
      key: key,
    });
  }

  // note - this code must match what is used for send-later!

  personalizeBodyForRecipient(_body, recipient) {
    const addRecipientToUrl = (originalUrl, email) => {
      const parsed = url.parse(originalUrl, true);
      const query = parsed.query || {};
      query.recipient = email;
      parsed.query = query;
      parsed.search = null; // so the format will use the query. See url docs.
      return parsed.format();
    };

    let body = _body;

    // This adds a `recipient` param to the open tracking src url.
    body = body.replace(/<img class="mailspring-open".*?src="(.*?)">/g, (match, src) => {
      const newSrc = addRecipientToUrl(src, recipient.email);
      return `<img class="mailspring-open" width="0" height="0" style="border:0; width:0; height:0;" src="${newSrc}">`;
    });

    // This adds a `recipient` param to the link tracking tracking href url.
    const trackedLinkRegexp = new RegExp(
      /(<a.*?href\s*?=\s*?['"])((?!mailto).+?)(['"].*?>)([\s\S]*?)(<\/a>)/gim
    );

    body = body.replace(trackedLinkRegexp, (match, prefix, href, suffix, content, closingTag) => {
      const newHref = addRecipientToUrl(href, recipient.email);
      return `${prefix}${newHref}${suffix}${content}${closingTag}`;
    });

    body = body.replace('data-open-tracking-src=', 'src=');

    return body;
  }
}
