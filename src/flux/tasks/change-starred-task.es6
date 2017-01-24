/* eslint no-unused-vars: 0*/
import _ from 'underscore';
import Thread from '../models/thread';
import Actions from '../actions'
import DatabaseStore from '../stores/database-store';
import ChangeMailTask from './change-mail-task';

export default class ChangeStarredTask extends ChangeMailTask {
  constructor(options = {}) {
    super(options);
    this.source = options.source;
    this.starred = options.starred;
  }

  label() {
    return this.starred ? "Starring" : "Unstarring";
  }

  description() {
    const count = this.threads.length;
    const type = count > 1 ? "threads" : "thread";

    if (this._isUndoTask) {
      return `Undoing changes to ${count} ${type}`
    }

    const verb = this.starred ? "Starred" : "Unstarred";
    if (count > 1) {
      return `${verb} ${count} ${type}`;
    }
    return `${verb}`;
  }

  performLocal() {
    if (this.threads.length === 0) {
      return Promise.reject(new Error("ChangeStarredTask: You must provide a `threads` Array of models or IDs."));
    }
    return super.performLocal();
  }

  recordUserEvent() {
    if (this.source === "Mail Rules") {
      return
    }
    const eventName = this.unread ? "Starred" : "Unstarred";
    Actions.recordUserEvent(`Threads ${eventName}`, {
      source: this.source,
      numThreads: this.threads.length,
      description: this.description(),
      isUndo: this._isUndoTask,
    })
  }

  retrieveModels() {
    return Promise.props({
      threads: DatabaseStore.modelify(Thread, this.threads),
    }).then(({threads}) => {
      this.threads = _.compact(threads);
      return Promise.resolve();
    })
  }

  changesToModel(model) {
    return {starred: this.starred};
  }

  requestBodyForModel(model) {
    return {starred: model.starred};
  }
}
