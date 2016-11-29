import Task from './task';
import Actions from '../actions';
import DatabaseStore from '../stores/database-store';
import NylasAPI from '../nylas-api';
import NylasAPIRequest from '../nylas-api-request';
import Message from '../models/message';
import BaseDraftTask from './base-draft-task';
import SyncbackMetadataTask from './syncback-metadata-task';
import {APIError} from '../errors';


export default class SyncbackDraftTask extends BaseDraftTask {

  performRemote() {
    return this.refreshDraftReference()
    .then(() =>
      new NylasAPIRequest({
        api: NylasAPI,
        options: {
          accountId: this.draft.accountId,
          path: (this.draft.serverId) ? `/drafts/${this.draft.serverId}` : "/drafts",
          method: (this.draft.serverId) ? 'PUT' : 'POST',
          body: this.draft.toJSON(),
          returnsModel: false,
        },
      })
      .run()
      .then(this.applyResponseToDraft)
      .thenReturn(Task.Status.Success)
    )
    .catch((err) => {
      if (err instanceof BaseDraftTask.DraftNotFoundError) {
        return Promise.resolve(Task.Status.Continue);
      }
      if ((err instanceof APIError) && (!NylasAPI.PermanentErrorCodes.includes(err.statusCode))) {
        return Promise.resolve(Task.Status.Retry);
      }
      return Promise.resolve([Task.Status.Failed, err]);
    });
  }

  applyResponseToDraft = (response) => {
    // Important: There could be a significant delay between us initiating the save
    // and getting JSON back from the server. Our local copy of the draft may have
    // already changed more.

    // The only fields we want to update from the server are the `id` and `version`.

    return DatabaseStore.inTransaction((t) => {
      return this.refreshDraftReference().then(() => {
        if (this.draft.serverId !== response.id) {
          this.draft.threadId = response.thread_id;
          this.draft.serverId = response.id;
        }
        this.draft.version = response.version;
        return t.persistModel(this.draft);
      });
    })
    .then(() => {
      for (const {pluginId} of this.draft.pluginMetadata) {
        const task = new SyncbackMetadataTask(this.draftClientId, Message.name, pluginId);
        Actions.queueTask(task);
      }
      return true;
    });
  }
}
