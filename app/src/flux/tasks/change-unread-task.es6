/* eslint no-unused-vars: 0*/
import _ from 'underscore';
import Thread from '../models/thread';
import Actions from '../actions';
import Attributes from '../attributes';
import DatabaseStore from '../stores/database-store';
import ChangeMailTask from './change-mail-task';

export default class ChangeUnreadTask extends ChangeMailTask {
  static attributes = Object.assign({}, ChangeMailTask.attributes, {
    unread: Attributes.Boolean({
      modelKey: 'unread',
    }),
  });

  constructor(data = {}) {
    if (data.threads) {
      data.threads = data.threads.filter(t => t.unread !== data.unread);
    }
    if (data.messages) {
      data.messages = data.messages.filter(m => m.unread !== data.unread);
    }
    super(data);
  }

  label() {
    return this.unread ? 'Marking as unread' : 'Marking as read';
  }

  description() {
    const count = this.threadIds.length;
    const type = count > 1 ? 'threads' : 'thread';

    if (this.isUndo) {
      return `Undoing changes to ${count} ${type}`;
    }

    const newState = this.unread ? 'unread' : 'read';
    if (count > 1) {
      return `Marked ${count} ${type} as ${newState}`;
    }
    return `Marked as ${newState}`;
  }

  createUndoTask() {
    const task = super.createUndoTask();
    task.unread = !this.unread;
    return task;
  }
}
