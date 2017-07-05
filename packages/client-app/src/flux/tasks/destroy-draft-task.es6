import Task from './task';

export default class DestroyDraftTask extends Task {
  constructor(accountId, headerMessageId) {
    super();
    this.accountId = accountId;
    this.headerMessageId = headerMessageId;
  }
}
