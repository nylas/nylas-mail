import _ from 'underscore';
import Task from './task';
import Thread from '../models/thread';
import Message from '../models/message';

/*
Public: The ChangeMailTask is a base class for all tasks that modify sets
of threads or messages.

Subclasses implement {ChangeMailTask::changesToModel} and
{ChangeMailTask::requestBodyForModel} to define the specific transforms
they provide, and override {ChangeMailTask::performLocal} to perform
additional consistency checks.

ChangeMailTask aims to be fast and efficient. It does not write changes to
the database or make API requests for models that are unmodified by
{ChangeMailTask::changesToModel}

ChangeMailTask stores the previous values of all models it changes into
this._restoreValues and handles undo/redo. When undoing, it restores previous
values and calls {ChangeMailTask::requestBodyForModel} to make undo API
requests. It does not call {ChangeMailTask::changesToModel}.
*/
export default class ChangeMailTask extends Task {

  constructor({threads, thread, messages, message} = {}) {
    super();

    const t = threads || [];
    if (thread) {
      t.push(thread);
    }
    const m = messages || [];
    if (message) {
      m.push(message);
    }

    // we actually only keep a small bit of data now
    this.threadIds = t.map(i => i.id);
    this.messageIds = m.map(i => i.id);
    this.accountId = (t[0] || m[0] || {}).accountId;
  }

  // Task lifecycle

  canBeUndone() {
    return true;
  }

  isUndo() {
    return this._isUndoTask === true;
  }

  createUndoTask() {
    if (this._isUndoTask) {
      throw new Error("ChangeMailTask::createUndoTask Cannot create an undo task from an undo task.");
    }
    if (!this._restoreValues) {
      throw new Error("ChangeMailTask::createUndoTask Cannot undo a task which has not finished performLocal yet.");
    }

    const task = this.createIdenticalTask();
    task._restoreValues = this._restoreValues;
    task._isUndoTask = true;
    return task;
  }

  createIdenticalTask() {
    return new this.constructor(this);
  }

  objectIds() {
    return [].concat(this.threadIds, this.messageIds);
  }

  objectClass() {
    return (this.threadIds && this.threadIds.length) ? Thread : Message;
  }

  numberOfImpactedItems() {
    return this.objectIds().length;
  }

}
