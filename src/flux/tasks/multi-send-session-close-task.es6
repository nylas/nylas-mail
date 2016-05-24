import Task from './task';
import {APIError} from '../errors';
import NylasAPI from '../nylas-api';
import MultiSendToIndividualTask from './multi-send-to-individual-task';


export default class MultiSendSessionCloseTask extends Task {
  constructor(opts = {}) {
    super(opts);
    this.message = opts.message;
  }

  isDependentOnTask(other) {
    return (other instanceof MultiSendToIndividualTask) && (other.message.clientId === this.message.clientId);
  }

  performRemote() {
    return NylasAPI.makeRequest({
      method: "DELETE",
      path: `/send-multiple/${this.message.id}`,
      accountId: this.message.accountId,
    })
    .then(() => {
      return Promise.resolve(Task.Status.Success);
    })
    .catch((err) => {
      const errorMessage = `We had trouble saving this message to your Sent folder.\n\n${err.message}`;
      if (err instanceof APIError) {
        if (NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
          NylasEnv.showErrorDialog(errorMessage, {showInMainWindow: true});
          return Promise.resolve([Task.Status.Failed, err]);
        }
        return Promise.resolve(Task.Status.Retry);
      }
      NylasEnv.reportError(err);
      NylasEnv.showErrorDialog(errorMessage, {showInMainWindow: true});
      return Promise.resolve([Task.Status.Failed, err]);
    });
  }
}
