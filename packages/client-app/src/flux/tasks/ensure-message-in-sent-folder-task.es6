import Task from './task';
import {APIError} from '../errors';
import Actions from '../actions';
import NylasAPI from '../nylas-api';
import SyncbackTaskAPIRequest from '../syncback-task-api-request';
import SendDraftTask from './send-draft-task';


export default class EnsureMessageInSentFolderTask extends Task {
  constructor(opts = {}) {
    super(opts);
    this.message = opts.message;
    this.customSentMessage = opts.customSentMessage;
  }

  label() {
    return "Saving to sent folder";
  }

  isDependentOnTask(other) {
    return (other instanceof SendDraftTask) && (other.message) && (other.message.clientId === this.message.clientId);
  }

  performLocal() {
    if (!this.message) {
      const errMsg = `Attempt to call ${this.constructor.name}.performLocal without a message`;
      return Promise.reject(new Error(errMsg));
    }
    return Promise.resolve();
  }

  performRemote() {
    let runPromise = Promise.resolve();
    if (this._syncbackRequestId) {
      runPromise = SyncbackTaskAPIRequest.waitForQueuedRequest(this._syncbackRequestId)
    } else {
      runPromise = new SyncbackTaskAPIRequest({
        api: NylasAPI,
        options: {
          path: `/ensure-message-in-sent-folder/${this.message.id}`,
          method: "POST",
          body: {
            customSentMessage: this.customSentMessage,
          },
          accountId: this.message.accountId,
          onSyncbackRequestCreated: (syncbackRequest) => {
            this._syncbackRequestId = syncbackRequest.id
          },
        },
      }).run()
    }

    return runPromise.then(() => {
      Actions.ensureMessageInSentSuccess({messageClientId: this.message.clientId})
      return Task.Status.Success
    })
    .catch((err) => {
      const errorMessage = `Your message successfully sent; however, we had trouble saving your message, "${this.message.subject}", to your Sent folder.\n\n${err.message}`;
      if (err instanceof APIError) {
        if (NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
          NylasEnv.showErrorDialog(errorMessage, {showInMainWindow: true, detail: err.stack});
          return Promise.resolve([Task.Status.Failed, err]);
        }
        return Promise.resolve(Task.Status.Retry);
      }
      NylasEnv.reportError(err);
      NylasEnv.showErrorDialog(errorMessage, {showInMainWindow: true, detail: err.stack});
      return Promise.resolve([Task.Status.Failed, err]);
    });
  }
}
