import _ from 'underscore'
import Task from './task';
import Actions from '../actions';
import {APIError} from '../errors';
import NylasAPI from '../nylas-api';
import * as NylasAPIHelpers from '../nylas-api-helpers';
import NylasAPIRequest from '../nylas-api-request';
import TaskQueue from '../../flux/stores/task-queue';
import SoundRegistry from '../../registries/sound-registry';
import MultiSendToIndividualTask from './multi-send-to-individual-task';


export default class MultiSendSessionCloseTask extends Task {
  constructor(opts = {}) {
    super(opts);
    this.draft = opts.draft;
    this.message = opts.message;
  }

  isDependentOnTask(other) {
    return (other instanceof MultiSendToIndividualTask) && (other.message.clientId === this.message.clientId);
  }

  shouldBeDequeuedOnDependencyFailure() {
    return false
  }

  showDependentErrors = () => {
    const failedTasks = TaskQueue.findTasks(MultiSendToIndividualTask, (task) => {
      return (task.queueState.status === Task.Status.Failed &&
        task.message.id === this.message.id)
    }, {includeCompleted: true})
    if (failedTasks.length > 0) {
      let errorMessages = failedTasks.map((task) => {
        return (task.queueState.remoteError || {}).message
      })
      errorMessages = _.uniq(_.compact(errorMessages)).join("\n\n")

      const emails = failedTasks.map(t => t.recipient.email).join(", ")

      const errorMessage = `We had trouble sending this message to all recipients. ${emails} may not have received this email.\n\n${errorMessages}`;

      NylasEnv.showErrorDialog(errorMessage, {showInMainWindow: true});
    }
  }

  performRemote() {
    return new NylasAPIRequest({
      api: NylasAPI,
      options: {
        timeout: 1000 * 60 * 5, // We cannot hang up a send - won't know if it sent
        method: "DELETE",
        path: `/send-multiple/${this.message.id}`,
        accountId: this.message.accountId,
      },
    })
    .run()
    .then(() => {
      // TODO: This is duplicated from SendDraftTask!
      Actions.recordUserEvent("Draft Sent")
      Actions.sendDraftSuccess({message: this.message, messageClientId: this.message.clientId, draftClientId: this.draft.clientId});
      NylasAPIHelpers.makeDraftDeletionRequest(this.draft);

      // Play the sending sound
      if (NylasEnv.config.get("core.sending.sounds")) {
        SoundRegistry.playSound('send');
      }

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
    }).finally(this.showDependentErrors);
  }
}
