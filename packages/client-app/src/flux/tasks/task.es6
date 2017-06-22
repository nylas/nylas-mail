/* eslint no-unused-vars: 0*/
import _ from 'underscore';
import Model from '../models/model';
import {generateTempId} from '../models/utils';
import {PermanentErrorCodes} from '../nylas-api';
import {APIError} from '../errors';

const TaskStatus = {
  Retry: "RETRY",
  Success: "SUCCESS",
  Continue: "CONTINUE",
  Failed: "FAILED",
};

export default class Task extends Model {

  static Status = TaskStatus;
  static SubclassesUseModelTable = Task;

  // Public: Override the constructor to pass initial args to your Task and
  // initialize instance variables.
  //
  // **IMPORTANT:** if (you override the constructor, be sure to call)
  // `super`.
  //
  // On construction, all Tasks instances are given a unique `id`.
  constructor() {
    super();
    this._rememberedToCallSuper = true;
    this.id = generateTempId();
    this.sequentialId = null; // set when queued
    this.queueState = {
      isProcessing: false,
      localError: null,
      localComplete: false,
      remoteError: null,
      remoteAttempts: 0,
      remoteComplete: false,
      status: null,
    };
  }

  // Private: This is a internal wrapper around `performLocal`
  runLocal() {
    if (!this._rememberedToCallSuper) {
      throw new Error("Your must call `super` from your Task's constructors");
    }

    if (this.queueState.localComplete) {
      return Promise.resolve();
    }

    try {
      return this.performLocal()
      .then(() => {
        this.queueState.localComplete = true;
        this.queueState.localError = null;
        return Promise.resolve();
      })
      .catch(this._handleLocalError);
    } catch (err) {
      return this._handleLocalError(err);
    }
  }

  _handleLocalError = (err) => {
    this.queueState.localError = err;
    this.queueState.status = Task.Status.Failed;
    NylasEnv.reportError(err);
    return Promise.reject(err);
  }


  // HELPER METHODS
  validateRequiredFields = (fields = []) => {
    for (const field of fields) {
      if (!this[field]) {
        throw new Error(`Must pass ${field}`);
      }
    }
  }

  // METHODS TO OBSERVE
  //
  // Public: **Required** | Override to perform local, optimistic updates.
  //
  // Most tasks will put code in here that updates the {DatabaseStore}
  //
  // You should also implement the rollback behavior inside of
  // `performLocal` or in some helper method. It's common practice (but not
  // automatic) for `performLocal` to be re-called at the end of an API
  // failure from `performRemote`.
  //
  // That rollback behavior is also likely the same when you want to undo a
  // task. It's common practice (but not automatic) for `createUndoTask` to
  // set some flag that `performLocal` will recognize to implement the
  // rollback behavior.
  //
  // `performLocal` will complete BEFORE the task actually enters the
  // {TaskQueue}.
  //
  // if (you would like to do work after `performLocal` has run, you can use)
  // {TaskQueue::waitForPerformLocal}. Pass it the task and it
  // will return a Promise that resolves once the local action has
  // completed. This is contained in the {TaskQueue} so you can
  // listen to tasks across windows.
  //
  // ## Examples
  //
  // ### Simple Optimistic Updating
  //
  // ```js
  // class MyTask extends Task {
  //   performLocal() {
  //     this.updatedModel = this._myModelUpdateCode()
  //     return DatabaseStore.inTransaction((t) => persistModel(this.updatedModel));
  //   }
  // }
  // ```
  //
  // ### Handling rollback on API failure
  //
  // ```js
  // class MyTask extends Task
  //   performLocal() {
  //     if (this._reverting) {
  //       this.updatedModel = this._myModelRollbackCode();
  //     } else {
  //       this.updatedModel = this._myModelUpdateCode();
  //     }
  //     return DatabaseStore.inTransaction((t) => persistModel(this.updatedModel));
  //   }
  //   performRemote() {
  //     return this._APIPutHelperMethod(this.updatedModel).catch((apiError) => {
  //       if (apiError.statusCode === 500) {
  //         this._reverting = true;
  //         return this.performLocal();
  //       }
  //     }
  //   }
  // }
  // ```
  //
  // ### Handling an undo task
  //
  // ```js
  // class MyTask extends Task {
  //   performLocal() {
  //     if (this._isUndoTask) {
  //       this.updatedModel = this._myModelRollbackCode();
  //     } else {
  //       this.updatedModel = this._myModelUpdateCode();
  //     }
  //     return DatabaseStore.inTransaction((t) => persistModel(this.updatedModel));
  //   }
  //
  //   createUndoTask() {
  //     undoTask = this.createIdenticalTask();
  //     undoTask._isUndoTask = true;
  //     return undoTask;
  //   }
  // }
  // ```
  //
  // Also see the documentation on the required undo methods
  //
  // Returns a {Promise} that resolves when your updates are complete.
  performLocal() {
    return Promise.resolve();
  }

  // Public: It's up to you to determine how you want to indicate whether
  // or not you have an instance of an "Undo Task". We commonly use a
  // simple instance variable boolean flag.
  //
  // Returns `true` (is an Undo Task) or `false` (is not an Undo Task)
  isUndo() {
    return false;
  }

  // Public: Determines whether or not this task can be undone via the
  // {UndoRedoStore}
  //
  // Returns `true` (can be undone) or `false` (can't be undone)
  canBeUndone() {
    return false;
  }

  // Public: Return from `createIdenticalTask` and set a flag so your
  // `performLocal` and `performRemote` methods know that this is an undo
  // task.
  createUndoTask() {
    throw new Error("Unimplemented");
  }

  // Public: Return a deep-cloned task to be used for an undo task
  createIdenticalTask() {
    const json = this.toJSON();
    delete json.queueState;
    return (new this.constructor()).fromJSON(json);
  }

  // Public: code to run if (someone tries to dequeue your task while it is)
  // in flight.
  //
  cancel() {

  }

  // Public: (optional) A string displayed to users when your task is run.
  //
  // When tasks are run, we automatically display a notification to users
  // of the form "label (numberOfImpactedItems)". if (this does not a return)
  // a string, no notification is displayed
  label() {

  }

  // Public: A string displayed to users indicating how many items your
  // task affected.
  numberOfImpactedItems() {
    return 1;
  }

  // Private: Allows for serialization of tasks
  toJSON() {
    return this;
  }

  // Private: Allows for deserialization of tasks
  fromJSON(json) {
    for (const key of Object.keys(json)) {
      this[key] = json[key];
    }
    return this;
  }
}
