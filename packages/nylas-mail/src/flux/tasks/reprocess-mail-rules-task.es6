import _ from 'underscore';
import async from 'async';

import Task from './task';
import Thread from '../models/thread';
import Message from '../models/message';
import DatabaseStore from '../stores/database-store';
import CategoryStore from '../stores/category-store';
import MailRulesProcessor from '../../mail-rules-processor';

export default class ReprocessMailRulesTask extends Task {
  constructor(accountId) {
    super();
    this.accountId = accountId;
    this._processed = this._processed || 0;
    this._offset = this._offset || 0;
    this._lastTimestamp = this._lastTimestamp || null;
    this._finished = false;
  }

  label() {
    return "Applying Mail Rules";
  }

  numberOfImpactedItems() {
    return this._offset;
  }

  cancel() {
    this._finished = true;
  }

  performRemote() {
    return Promise.fromCallback(this._processAllMessages).thenReturn(Task.Status.Success);
  }

  _processAllMessages = (callback) => {
    async.until(() => this._finished, this._processSomeMessages, callback);
  }

  _processSomeMessages = (callback) => {
    const inboxCategory = CategoryStore.getStandardCategory(this.accountId, 'inbox');
    if (!inboxCategory) {
      return callback(new Error("ReprocessMailRulesTask: No inbox category found."));
    }

    // Fetching threads first, and then getting their messages allows us to use
    // The same indexes as the thread list / message list in the app

    // Note that we look for "50 after X" rather than "offset 150", because
    // running mail rules can move things out of the inbox!
    const query = DatabaseStore
      .findAll(Thread, {accountId: this.accountId})
      .where(Thread.attributes.categories.contains(inboxCategory.id))
      .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
      .limit(50)

    if (this._lastTimestamp !== null) {
      query.where(Thread.attributes.lastMessageReceivedTimestamp.lessThan(this._lastTimestamp))
    }

    return query.then((threads) => {
      if (threads.length === 0) {
        this._finished = true;
      }

      if (this._finished) {
        return Promise.resolve(null);
      }

      return DatabaseStore.findAll(Message, {threadId: _.pluck(threads, 'id')}).then((messages) => {
        if (this._finished) {
          return Promise.resolve(null);
        }

        return MailRulesProcessor.processMessages(messages).finally(() => {
          this._processed += messages.length;
          this._offset += threads.length;
          this._lastTimestamp = threads.pop().lastMessageReceivedTimestamp;
        });
      });
    })
    .delay(500)
    .asCallback(callback)
  }
}
