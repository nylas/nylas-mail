import Task from './task';
import {APIError} from '../errors';
import Message from '../models/message';
import DatabaseStore from '../stores/database-store';
import NylasAPI from '../nylas-api';
import NylasAPIRequest from '../nylas-api-request';
import BaseDraftTask from './base-draft-task';

export default class DestroyDraftTask extends BaseDraftTask {

  shouldDequeueOtherTask(other) {
    return (other instanceof BaseDraftTask && other.draftClientId === this.draftClientId);
  }

  performLocal() {
    super.performLocal();
    return this.refreshDraftReference()
    .then(() => DatabaseStore.inTransaction((t) => t.unpersistModel(this.draft)))
    .catch(BaseDraftTask.DraftNotFoundError, () => Promise.resolve());
  }

  performRemote() {
    // We don't need to do anything if we weren't able to find the draft
    // when we performed locally, or if the draft has never been synced to
    // the server (id is still self-assigned)
    if (!this.draft) {
      return Promise.resolve(Task.Status.Continue);
    }
    if (!this.draft.serverId) {
      return Promise.resolve(Task.Status.Continue);
    }
    if (!this.draft.version) {
      const err = new Error("Can't destroy draft without a version or serverId");
      return Promise.resolve([Task.Status.Failed, err]);
    }

    NylasAPI.incrementRemoteChangeLock(Message, this.draft.serverId);

    return new NylasAPIRequest({
      api: NylasAPI,
      options: {
        path: `/drafts/${this.draft.serverId}`,
        accountId: this.draft.accountId,
        method: "DELETE",
        body: {
          version: this.draft.version,
        },
      },
    })
    .run()
    // We deliberately do not decrement the change count, ensuring no deltas
    // about this object are received that could restore it.
    .thenReturn(Task.Status.Success)
    .catch(APIError, (err) => {
      NylasAPI.decrementRemoteChangeLock(Message, this.draft.serverId);

      const inboxMsg = (err.body && err.body.message) ? err.body.message : '';

      // Draft has already been deleted, this is not really an error
      if ([404, 409].includes(err.statusCode)) {
        return Promise.resolve(Task.Status.Continue);
      }
      // Draft has been sent, and can't be deleted. Not much we can do but finish
      if (inboxMsg.indexOf("is not a draft") >= 0) {
        return Promise.resolve(Task.Status.Continue);
      }
      if (!NylasAPI.PermanentErrorCodes.inclue(err.statusCode)) {
        return Promise.resolve(Task.Status.Retry);
      }

      NylasEnv.showErrorDialog("Unable to delete this draft. Restoring...");

      return DatabaseStore.inTransaction((t) =>
        t.persistModel(this.draft)
      ).then(() =>
        Promise.resolve(Task.Status.Failed)
      )
    })
  }
}
