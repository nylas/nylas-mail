import Task from './task';
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
    return (other instanceof SendDraftTask) && (other.message) && (other.message.id === this.message.id);
  }

  performLocal() {
    if (!this.message) {
      const errMsg = `Attempt to call ${this.constructor.name}.performLocal without a message`;
      return Promise.reject(new Error(errMsg));
    }
    return Promise.resolve();
  }
}
