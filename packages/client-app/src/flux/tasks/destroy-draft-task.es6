import BaseDraftTask from './base-draft-task';

export default class DestroyDraftTask extends BaseDraftTask {
  constructor(headerMessageId) {
    super();
    this.headerMessageId = headerMessageId;
  }
}
