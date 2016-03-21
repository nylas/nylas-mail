import _ from 'underscore';
import Task from './task';
import Thread from '../models/thread';
import Message from '../models/message';
import DatabaseStore from '../stores/database-store';
import MailRulesProcessor from '../../mail-rules-processor';
import async from 'async';

export default class ReprocessMailRulesTask extends Task {
  constructor(accountId) {
    super();
    this.accountId = accountId;
    this._processed = this._processed || 0;
    this._offset = this._offset || 0;
    this._finished = false;
  }

  label() {
    return "Applying Mail Rules...";
  }

  numberOfImpactedItems() {
    return this._offset;
  }

  cancel() {
    this._finished = true;
  }

  performRemote() {
    return Promise.fromNode(this._processAllMessages).thenReturn(Task.Status.Success);
  }

  _processAllMessages = (callback) => {
    async.until(() => this._finished, this._processSomeMessages, callback);
  }

  _processSomeMessages = (callback) => {
    // Fetching threads first, and then getting their messages allows us to use
    // The same indexes as the thread list / message list in the app
    const query = DatabaseStore
      .findAll(Thread, {accountId: this.accountId})
      .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
      .offset(this._offset)
      .limit(50)

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
        });
      });
    })
    .delay(500)
    .asCallback(callback)
  }
}
