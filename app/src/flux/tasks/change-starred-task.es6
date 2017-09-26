/* eslint no-unused-vars: 0*/
import _ from 'underscore';
import Attributes from '../attributes';
import Thread from '../models/thread';
import Actions from '../actions';
import DatabaseStore from '../stores/database-store';
import ChangeMailTask from './change-mail-task';

export default class ChangeStarredTask extends ChangeMailTask {
  static attributes = Object.assign({}, ChangeMailTask.attributes, {
    starred: Attributes.Boolean({
      modelKey: 'starred',
    }),
  });

  constructor(data = {}) {
    if (data.threads) {
      data.threads = data.threads.filter(t => t.starred !== data.starred);
    }
    if (data.messages) {
      data.messages = data.messages.filter(m => m.starred !== data.starred);
    }
    super(data);
  }

  label() {
    return this.starred ? 'Starring' : 'Unstarring';
  }

  description() {
    const count = this.threadIds.length;
    const type = count > 1 ? 'threads' : 'thread';

    if (this.isUndo) {
      return `Undoing changes to ${count} ${type}`;
    }

    const verb = this.starred ? 'Starred' : 'Unstarred';
    if (count > 1) {
      return `${verb} ${count} ${type}`;
    }
    return `${verb}`;
  }

  validate() {
    if (this.threadIds.length === 0) {
      throw new Error('ChangeStarredTask: You must provide a `threads` Array of models or IDs.');
    }
    super.validate();
  }

  createUndoTask() {
    const task = super.createUndoTask();
    task.starred = !this.starred;
    return task;
  }

  recordUserEvent() {
    if (this.source === 'Mail Rules') {
      return;
    }
    const eventName = this.starred ? 'Starred' : 'Unstarred';
    Actions.recordUserEvent(`Threads ${eventName}`, {
      source: this.source,
      numThreads: this.threadIds.length,
      description: this.description(),
      isUndo: this.isUndo,
    });
  }
}
