import Task from './task';

export default class SyncbackDraftTask extends Task {
  constructor(draft) {
    super();
    this.draft = draft;
    this.accountId = (draft || {}).accountId;
    this.headerMessageId = (draft || {}).headerMessageId;
  }
}
