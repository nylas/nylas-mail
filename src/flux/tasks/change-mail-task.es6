import _ from 'underscore';
import Task from './task';
import Thread from '../models/thread';
import Message from '../models/message';
import NylasAPI from '../nylas-api';
import SyncbackTaskAPIRequest from '../syncback-task-api-request';
import DatabaseStore from '../stores/database-store';
import {APIError} from '../errors';
import EnsureMessageInSentFolderTask from './ensure-message-in-sent-folder-task'

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

    this.threads = threads || [];
    if (thread) {
      this.threads.push(thread);
    }
    this.messages = messages || [];
    if (message) {
      this.messages.push(message);
    }
  }

  // Functions for subclasses

  // Public: Override this method and return an object with key-value pairs
  // representing changed values. For example, if (your task sets unread:)
  // false, return {unread: false}.
  //
  // - `model` an individual {Thread} or {Message}
  //
  // Returns an object whos key-value pairs represent the desired changed
  // object.
  changesToModel() {
    throw new Error("You must override this method.");
  }

  // Public: Override this method and return an object that will be the
  // request body used for saving changes to `model`.
  //
  // - `model` an individual {Thread} or {Message}
  //
  // Returns an object that will be passed as the `body` to the actual API
  // `request` object
  requestBodyForModel() {
    throw new Error("You must override this method.");
  }

  // Public: Override to indicate whether actions need to be taken for all
  // messages of each thread.
  //
  // Generally, you cannot provide both messages and threads at the same
  // time. However, ChangeMailTask runs for provided threads first and then
  // messages. Override and return true, and you will receive
  // `changesToModel` for messages in changed threads, and any changes you
  // make will be written to the database and undone during undo.
  //
  // Note that API requests are only made for threads if (threads are)
  // present.
  processNestedMessages() {
    return false;
  }

  // Public: Returns categories that this task will add to the set of threads
  // Must be overriden
  categoriesToAdd() {
    return [];
  }

  // Public: Returns categories that this task will remove the set of threads
  // Must be overriden
  categoriesToRemove() {
    return [];
  }

  // Public: Subclasses should override `performLocal` and call super once
  // they've prepared the data they need and verified that requirements are
  // met.

  // See {Task::performLocal} for more usage info

  performLocal() {
    if (this._isUndoTask && !this._restoreValues) {
      return Promise.reject(new Error("ChangeMailTask: No _restoreValues provided for undo task."))
    }
    // Lock the models with the optimistic change tracker so they aren't reverted
    // while the user is seeing our optimistic changes.
    if (!this._isReverting) {
      this._lockAll();
    }

    return DatabaseStore.inTransaction((t) => {
      return this.retrieveModels().then(() => {
        return this._performLocalThreads(t)
      }).then(() => {
        return this._performLocalMessages(t)
      })
    }).then(() => {
      try {
        this.recordUserEvent()
      } catch (err) {
        NylasEnv.reportError(err);
        // don't throw
      }
    });
  }

  recordUserEvent() {
    throw new Error("Override recordUserEvent")
  }

  retrieveModels() {
    // Note: Currently, *ALL* subclasses must use `DatabaseStore.modelify`
    // to convert `threads` and `messages` from models or ids to models.
    return Promise.resolve();
  }

  _performLocalThreads(transaction) {
    const changed = this._applyChanges(this.threads);
    const changedIds = _.pluck(changed, 'id');

    if (changed.length === 0) {
      return Promise.resolve();
    }

    return transaction.persistModels(changed).then(() => {
      if (!this.processNestedMessages()) {
        return Promise.resolve();
      }
      return DatabaseStore.findAll(Message).where(Message.attributes.threadId.in(changedIds)).then((messages) => {
        this.messages = [].concat(messages, this.messages);
        return Promise.resolve()
      })
    });
  }

  _performLocalMessages(transaction) {
    const changed = this._applyChanges(this.messages);
    return (changed.length > 0) ? transaction.persistModels(changed) : Promise.resolve();
  }

  _applyChanges(modelArray) {
    const changed = [];

    if (this._shouldChangeBackwards()) {
      modelArray.forEach((model, idx) => {
        if (this._restoreValues[model.id]) {
          const updated = _.extend(model.clone(), this._restoreValues[model.id]);
          modelArray[idx] = updated;
          changed.push(updated);
        }
      });
    } else {
      this._restoreValues = this._restoreValues || {};
      modelArray.forEach((model, idx) => {
        const fieldsNew = this.changesToModel(model);
        const fieldsCurrent = _.pick(model, Object.keys(fieldsNew));
        if (!_.isEqual(fieldsCurrent, fieldsNew)) {
          this._restoreValues[model.id] = fieldsCurrent;
          const updated = _.extend(model.clone(), fieldsNew);
          modelArray[idx] = updated;
          changed.push(updated);
        }
      });
    }

    return changed;
  }

  _shouldChangeBackwards() {
    return this._isReverting || this._isUndoTask;
  }

  performRemote() {
    return this._performRequests(this.objectClass(), this.objectArray())
    .then(() => {
      this._ensureLocksRemoved();
      return Promise.resolve(Task.Status.Success);
    })
    .catch((err) => {
      if (err instanceof APIError && !NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
        return Promise.resolve(Task.Status.Retry);
      }
      this._isReverting = true;
      return this.performLocal()
      .then(() => {
        this._ensureLocksRemoved();
        NylasEnv.showErrorDialog({
          title: "Error",
          message: `We were unable to apply the changes to your thread${this.threads.length > 1 ? 's' : ''}, please try again!\nIf the error persists, contact support@nylas.com with the error message.\n\nError message: ${err.message}`,
        })
        return Promise.resolve([Task.Status.Failed, err]);
      });
    });
  }

  _performRequests(klass, models) {
    const alreadyQueued = Object.assign({}, this._syncbackRequestIds || {})
    return Promise.map(models, (model) => {
      if (alreadyQueued[model.id]) {
        return SyncbackTaskAPIRequest.waitForQueuedRequest(alreadyQueued[model.id])
      }

      const endpoint = (klass === Thread) ? 'threads' : 'messages';

      return new SyncbackTaskAPIRequest({
        api: NylasAPI,
        options: {
          path: `/${endpoint}/${model.id}`,
          accountId: model.accountId,
          method: 'PUT',
          body: this.requestBodyForModel(model),
          returnsModel: true,
          onSyncbackRequestCreated: (syncbackRequest) => {
            if (!this._syncbackRequestIds) this._syncbackRequestIds = {}
            this._syncbackRequestIds[model.id] = syncbackRequest.id
          },
        },
      })
      .run()
      .catch((err) => {
        if (err instanceof APIError && err.statusCode === 404) {
          return Promise.resolve();
        }
        return Promise.reject(err);
      })
    })
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
    const task = new this.constructor(this);

    // Never give the undo task the Model objects - make it look them up!
    // This ensures that they never revert other fields
    const toIds = (arr) => _.map(arr, v => (_.isString(v) ? v : v.id));
    task.threads = toIds(this.threads);
    task.messages = (this.threads.length > 0) ? [] : toIds(this.messages);
    return task;
  }

  objectIds() {
    return [].concat(this.threads, this.messages).map((v) =>
      (_.isString(v) ? v : v.id)
    );
  }

  objectClass() {
    return (this.threads && this.threads.length) ? Thread : Message;
  }

  objectArray() {
    return (this.threads && this.threads.length) ? this.threads : this.messages;
  }

  numberOfImpactedItems() {
    return this.objectArray().length;
  }

  // To ensure that complex offline actions are synced correctly, label/folder additions
  // and removals need to be applied in order. (For example, star many threads,
  // and then unstar one.)
  isDependentOnTask(other) {
    // Wait on EnsureMessageInSentFolderTask if it involves a message that
    // belongs to a thread we are trying to operate on
    if (other instanceof EnsureMessageInSentFolderTask && other.message) {
      const objectIds = this.objectIds()
      if (objectIds.includes(other.message.threadId)) {
        return true;
      }
      if (objectIds.includes(other.message.clientId) || objectIds.includes(other.message.serverId)) {
        return true;
      }
    }
    // Only wait on other tasks that are older and also involve the same threads
    if (!(other instanceof ChangeMailTask)) {
      return false;
    }
    const otherOlder = other.sequentialId < this.sequentialId;
    const otherSameObjs = _.intersection(other.objectIds(), this.objectIds()).length > 0;
    return otherOlder && otherSameObjs;
  }

  // Helpers used in subclasses

  _lockAll() {
    const klass = this.objectClass();
    this._locked = this._locked || {};
    for (const item of this.objectArray()) {
      this._locked[item.id] = this._locked[item.id] || 0;
      this._locked[item.id] += 1;
      NylasAPI.incrementRemoteChangeLock(klass, item.id);
    }
  }

  _removeLock(item) {
    const klass = this.objectClass();
    NylasAPI.decrementRemoteChangeLock(klass, item.id);
    this._locked[item.id] -= 1;
  }

  _ensureLocksRemoved() {
    const klass = this.objectClass()
    if (!this._locked) {
      return;
    }

    for (const id of Object.keys(this._locked)) {
      let count = this._locked[id];
      while (count > 0) {
        NylasAPI.decrementRemoteChangeLock(klass, id);
        count -= 1;
      }
    }
    this._locked = null;
  }
}
