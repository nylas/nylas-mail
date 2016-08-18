import Task from './task';
import {APIError} from '../errors';
import NylasAPI from '../nylas-api';
import {RegExpUtils} from 'nylas-exports';


export default class MultiSendToIndividualTask extends Task {
  constructor(opts = {}) {
    super(opts);
    this.message = opts.message;
    this.recipient = opts.recipient;
  }

  performRemote() {
    return NylasAPI.makeRequest({
      method: "POST",
      timeout: 1000 * 60 * 5, // We cannot hang up a send - won't know if it sent
      path: `/send-multiple/${this.message.id}`,
      accountId: this.message.accountId,
      body: {
        send_to: {
          email: this.recipient.email,
          name: this.recipient.name,
        },
        body: this._customizeTrackingForRecipient(this.message.body),
      },
    })
    .then(() => {
      return Promise.resolve(Task.Status.Success);
    })
    .catch((err) => {
      // NOTE: We do NOT show any error messages here since there may be
      // dozens of these tasks. The `MultieSendSessionCloseTask`
      // accumulates and shows the errors.
      if (err instanceof APIError) {
        return Promise.resolve([Task.Status.Failed, err]);
      }
      return Promise.resolve([Task.Status.Failed, err]);
    });
  }

  _customizeTrackingForRecipient(text) {
    const openTrackingId = NylasEnv.packages.pluginIdFor('open-tracking')
    const linkTrackingId = NylasEnv.packages.pluginIdFor('link-tracking')
    const usesOpenTracking = this.message.metadataForPluginId(openTrackingId)
    const usesLinkTracking = this.message.metadataForPluginId(linkTrackingId)

    const encodedEmail = btoa(this.recipient.email)
      .replace(/\+/g, '-')
      .replace(/\//g, '_');
    let body = text
    if (usesOpenTracking) {
      body = body.replace(/<img class="n1-open"[^<]+src="([a-zA-Z0-9-_:\/.]*)">/g, (match, url) => {
        return `<img class="n1-open" width="0" height="0" style="border:0; width:0; height:0;" src="${url}?r=${encodedEmail}">`;
      });
    }
    if (usesLinkTracking) {
      body = body.replace(RegExpUtils.urlLinkTagRegex(), (match, prefix, url, suffix, content, closingTag) => {
        return `${prefix}${url}&r=${encodedEmail}${suffix}${content}${closingTag}`;
      });
    }
    return body;
  }
}
