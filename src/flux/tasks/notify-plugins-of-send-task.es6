import Task from './task'
import {APIError} from '../errors'
import NylasAPI from '../nylas-api'
import EdgehillAPI from '../edgehill-api'
import SyncbackMetadataTask from './syncback-metadata-task'

/**
 * If a plugin:
 *
 * 1. Operates on a draft
 * 2. Has a backend component that needs to remotely access the sent
 *    message of the draft
 * 3. Inserts a reference to the draft on send
 *
 * The issue arises when you need to reference a message before it's sent.
 * For example, suppose you want to insert a link in the draft of the
 * form:
 *
 * https://mycustombackend.com/track/<message_id>
 *
 * That link needs to be inserted before the draft is sent. Since the
 * draft hasn't yet been sent, we don't have the message_id of the sent
 * message.
 *
 * You may ask, why don't we just save the draft to get a "server id" for
 * the draft? There are 2 current (March 2016) major problems with that:
 *
 * 1. Saved draft IDs aren't consistent. A draft's server ID is not
 * guaranteed to be it's messageID once it's sent. Drafts may be deleted
 * once a message is sent, or they may update over time.
 *
 * 2. Drafts are frequently sent without ever being saved. We will
 * send drafts by just POSTing the raw body and participants to the /send
 * endpoint of the API. We may never get any sort of server ID until
 * after the message has been sent.
 *
 * To fix this problem we instead use the draftClientId in our urls and
 * then after send, tell our backend what draftClientId maps to what
 * messageId.
 *
 * Now, when we insert a link into a draft, it's of the form:
 *
 * https://mycustombackend.com/track/<draftClientId>
 *
 * Then, by listening to for `Actions.sendDraftSuccess`, we queue this
 * task
 *
 * The task will POST to your backend url the draftClientId and the
 * coresponding messageId
 */
export default class NotifyPluginsOfSendTask extends Task {
  constructor(opts = {}) {
    super(opts)
    this.accountId = opts.accountId
    this.messageId = opts.messageId
    this.messageClientId = opts.messageClientId
    this.errorMessage = `We had trouble connecting to the plugin server. \
Any plugins you used in your sent message will not be available.`
  }

  isDependentOnTask(other) {
    return (other instanceof SyncbackMetadataTask) && (other.clientId === this.messageClientId)
  }

  performLocal() {
    this.validateRequiredFields([
      "messageId",
      "accountId",
      "messageClientId",
    ]);
    return Promise.resolve()
  }

  performRemote() {
    return new Promise((resolve) => {
      EdgehillAPI.makeRequest({
        method: "POST",
        path: "/plugins/send-successful",
        body: {
          message_id: this.messageId,
          account_id: this.accountId,
        },
        success: () => {
          return resolve(Task.Status.Success)
        },
        error: (err) => {
          if (err instanceof APIError) {
            const msg = `${this.errorMessage}\n\n${err.message}`
            if (NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
              NylasEnv.showErrorDialog(msg, {showInMainWindow: true})
              return resolve([Task.Status.Failed, err])
            }
            return resolve(Task.Status.Retry)
          }
          const msg = `${this.errorMessage}\n\n${err.message}`
          NylasEnv.reportError(err);
          NylasEnv.showErrorDialog(msg, {showInMainWindow: true})
          return resolve([Task.Status.Failed, err])
        },
      });
    });
  }
}
