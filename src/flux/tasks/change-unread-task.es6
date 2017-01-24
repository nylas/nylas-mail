/* eslint no-unused-vars: 0*/
import _ from 'underscore';
import Thread from '../models/thread';
import Actions from '../actions'
import DatabaseStore from '../stores/database-store';
import ChangeMailTask from './change-mail-task';

export default class ChangeUnreadTask extends ChangeMailTask {
  constructor(options = {}) {
    super(options);
    this.source = options.source;
    this.unread = options.unread;
  }

  label() {
    return this.unread ? "Marking as unread" : "Marking as read";
  }

  description() {
    const count = this.threads.length;
    const type = count > 1 ? 'threads' : 'thread';

    if (this._isUndoTask) {
      return `Undoing changes to ${count} ${type}`;
    }

    const newState = this.unread ? "unread" : "read";
    if (count > 1) {
      return `Marked ${count} ${type} as ${newState}`;
    }
    return `Marked as ${newState}`;
  }

  performLocal() {
    if (this.threads.length === 0) {
      return Promise.reject(new Error("ChangeUnreadTask: You must provide a `threads` Array of models or IDs."))
    }
    return super.performLocal();
  }

  recordUserEvent() {
    if (this.source === "Mail Rules") {
      return
    }
    const eventName = this.unread ? "Unread" : "Read";
    Actions.recordUserEvent(`Threads Marked as ${eventName}`, {
      source: this.source,
      numThreads: this.threads.length,
      description: this.description(),
      isUndo: this._isUndoTask,
    })
  }

  retrieveModels() {
    // Convert arrays of IDs or models to models.
    // modelify returns immediately if (no work is required)
    return Promise.props({
      threads: DatabaseStore.modelify(Thread, this.threads),
    }).then(({threads}) => {
      this.threads = _.compact(threads);
      return Promise.resolve();
    });
  }

  processNestedMessages() {
    return true;
  }

  changesToModel(model) {
    return {unread: this.unread};
  }

  requestBodyForModel(model) {
    return {unread: model.unread};
  }
}
