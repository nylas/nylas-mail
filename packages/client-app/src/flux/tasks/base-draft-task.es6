import Task from './task';
import DraftHelpers from '../stores/draft-helpers';

export default class BaseDraftTask extends Task {

  static DraftNotFoundError = DraftHelpers.DraftNotFoundError;

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
    // Set this task to be dependent on any and SendDraftTasks for the
    // same draft that were created first.  This, in conjunction with this
    // method on SendDraftTask, ensures that a send and a syncback never
    // run at the same time for a draft.

    // Require here rather than on top to avoid a circular dependency
    const isSameDraft = (other.draftClientId === this.draftClientId);
    const isOlderTask = (other.sequentialId < this.sequentialId);
    const isSaveOrSend = (other instanceof BaseDraftTask);
    return (isSameDraft && isOlderTask && isSaveOrSend);
  }

  performLocal() {
    if (!this.draftClientId) {
      const errMsg = `Attempt to call ${this.constructor.name}.performLocal without a draftClientId`;
      return Promise.reject(new Error(errMsg));
    }
    return Promise.resolve();
  }

  async refreshDraftReference() {
    this.draft = await DraftHelpers.refreshDraftReference(this.draftClientId)
    return this.draft;
  }
}
