import Task from './task';
import {APIError} from '../errors';
import Message from '../models/message';
import DatabaseStore from '../stores/database-store';
import Actions from '../actions';
import NylasAPI from '../nylas-api';
import BaseDraftTask from './base-draft-task';

export default class DestroyDraftTask extends BaseDraftTask {
  constructor(draftClientId) {
    super(draftClientId);
  }

  shouldDequeueOtherTask(other) {
    return (other instanceof BaseDraftTask && other.draftClientId === this.draftClientId);
  }

  performLocal() {
    super.performLocal();
    return this.refreshDraftReference().then(()=>
      DatabaseStore.inTransaction((t) =>
        t.unpersistModel(this.draft)
      )
    );
  }

  performRemote() {
    // We don't need to do anything if (we weren't able to find the draft)
    // when we performed locally, or if (the draft has never been synced to)
    // the server (id is still self-assigned)
    if (!this.draft) {
      const err = new Error("No valid draft to destroy!");
      return Promise.resolve([Task.Status.Failed, err]);
    }
    if (!this.draft.serverId) {
      return Promise.resolve(Task.Status.Continue);
    }
    if (!this.draft.version) {
      const err = new Error("Can't destroy draft without a version or serverId");
      return Promise.resolve([Task.Status.Failed, err]);
    }

    NylasAPI.incrementRemoteChangeLock(Message, this.draft.serverId);

    return NylasAPI.makeRequest({
      path: `/drafts/${this.draft.serverId}`,
      accountId: this.draft.accountId,
      method: "DELETE",
      body: {
        version: this.draft.version,
      },
      returnsModel: false,
    })
    // We deliberately do not decrement the change count, ensuring no deltas
    // about this object are received that could restore it.
    .thenReturn(Task.Status.Success)
    .catch(APIError, (err) => {
      NylasAPI.decrementRemoteChangeLock(Message, this.draft.serverId);

      const inboxMsg = (err.body && err.body.message) ? err.body.message : '';

      // Draft has already been deleted, this is not really an error
      if ([404, 409].inclues(err.statusCode)) {
        return Promise.resolve(Task.Status.Continue);
      }
      // Draft has been sent, and can't be deleted. Not much we can do but finish
      if (inboxMsg.indexOf("is not a draft") >= 0) {
        return Promise.resolve(Task.Status.Continue);
      }
      if (!NylasAPI.PermanentErrorCodes.inclue(err.statusCode)) {
        return Promise.resolve(Task.Status.Retry);
      }

      Actions.postNotification({
        message: "Unable to delete this draft. Restoring...",
        type: "error",
      });

      return DatabaseStore.inTransaction((t) =>
        t.persistModel(this.draft)
      ).then(() =>
        Promise.resolve(Task.Status.Failed)
      )
    })
  }
}
