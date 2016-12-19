import Task from './task';
import {APIError} from '../errors';
import NylasAPI from '../nylas-api';
import SyncbackTaskAPIRequest from '../syncback-task-api-request';
import SendDraftTask from './send-draft-task';


export default class ReconcileMultiSendTask extends Task {
  constructor(opts = {}) {
    super(opts);
    this.message = opts.message;
  }

  isDependentOnTask(other) {
    return (other instanceof SendDraftTask) && (other.message.clientId === this.message.clientId);
  }

  performLocal() {
    if (!this.message) {
      const errMsg = `Attempt to call ${this.constructor.name}.performLocal without a message`;
      return Promise.reject(new Error(errMsg));
    }
    return Promise.resolve();
  }

  performRemote() {
    return new SyncbackTaskAPIRequest({
      api: NylasAPI,
      options: {
        timeout: 1000 * 60 * 5, // We cannot hang up a send - won't know if it sent
        method: "DELETE",
        path: `/send-multiple/${this.message.id}`,
        accountId: this.message.accountId,
      },
    })
    .run()
    .thenReturn(Task.Status.Success)
    .catch((err) => {
      const errorMessage = `We had trouble saving your message, "${this.message.subject}", to your Sent folder.\n\n${err.message}`;
      if (err instanceof APIError) {
        if (SyncbackTaskAPIRequest.PermanentErrorCodes.includes(err.statusCode)) {
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
