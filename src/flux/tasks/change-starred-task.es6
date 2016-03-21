/* eslint no-unused-vars: 0*/
import _ from 'underscore';
import Thread from '../models/thread';
import DatabaseStore from '../stores/database-store';
import ChangeMailTask from './change-mail-task';

export default class ChangeStarredTask extends ChangeMailTask {
  constructor(options = {}) {
    super(options);
    this.starred = options.starred;
  }

  label() {
    return this.starred ? "Starring…" : "Unstarring…";
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
    // Convert arrays of IDs or models to models.
    // modelify returns immediately if (no work is required)
    return Promise.props({
      threads: DatabaseStore.modelify(Thread, this.threads),
    }).then(({threads}) => {
      this.threads = _.compact(threads);
      return super.performLocal();
    })
  }

  changesToModel(model) {
    return {starred: this.starred};
  }

  requestBodyForModel(model) {
    return {starred: model.starred};
  }
}
