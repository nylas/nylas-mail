import DatabaseStore from '../stores/database-store';
import Task from './task';
import Message from '../models/message';

class DraftNotFoundError extends Error {

}

export default class BaseDraftTask extends Task {

  static DraftNotFoundError = DraftNotFoundError;

  constructor(draftClientId) {
    super();
    this.draftClientId = draftClientId;
    this.draft = null;
  }

  shouldDequeueOtherTask(other) {
    const isSameDraft = (other.draftClientId === this.draftClientId);
    const isOlderTask = (other.sequentialId < this.sequentialId);
    const isExactClass = (other.constructor.name === this.constructor.name);
    return (isSameDraft && isOlderTask && isExactClass);
  }

  isDependentOnTask(other) {
    // Set this task to be dependent on any SyncbackDraftTasks and
    // SendDraftTasks for the same draft that were created first.
    // This, in conjunction with this method on SendDraftTask, ensures
    // that a send and a syncback never run at the same time for a draft.

    // Require here rather than on top to avoid a circular dependency
    const isSameDraft = (other.draftClientId === this.draftClientId);
    const isOlderTask = (other.sequentialId < this.sequentialId);
    const isSaveOrSend = (other instanceof BaseDraftTask);
    return (isSameDraft && isOlderTask && isSaveOrSend);
  }

  performLocal() {
    // SyncbackDraftTask does not do anything locally. You should persist your changes
    // to the local database directly or using a DraftStoreProxy, and then queue a
    // SyncbackDraftTask to send those changes to the server.
    if (!this.draftClientId) {
      const errMsg = `Attempt to call ${this.constructor.name}.performLocal without a draftClientId`;
      return Promise.reject(new Error(errMsg));
    }
    return Promise.resolve();
  }

  refreshDraftReference = () => {
    return DatabaseStore
    .findBy(Message, {clientId: this.draftClientId})
    .include(Message.attributes.body)
    .then((message) => {
      if (!message || !message.draft) {
        return Promise.reject(new DraftNotFoundError());
      }
      this.draft = message;
      return Promise.resolve(message);
    });
  }
}
