import Task from './task';
import Attributes from '../attributes';
import Message from '../models/message';

export default class SyncbackDraftTask extends Task {
  static attributes = Object.assign({}, Task.attributes, {
    headerMessageId: Attributes.String({
      modelKey: 'headerMessageId',
    }),
    draft: Attributes.Object({
      modelKey: 'draft',
      itemClass: Message,
    }),
  });

  constructor({ draft, ...rest } = {}) {
    super(rest);
    this.draft = draft;
    this.accountId = (draft || {}).accountId;
    this.headerMessageId = (draft || {}).headerMessageId;
  }
}
