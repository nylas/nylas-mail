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
}
