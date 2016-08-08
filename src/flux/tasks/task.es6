/* eslint no-unused-vars: 0*/
import _ from 'underscore';
import {generateTempId} from '../models/utils';
import {PermanentErrorCodes} from '../nylas-api';
import {APIError} from '../errors';

const TaskStatus = {
  Retry: "RETRY",
  Success: "SUCCESS",
  Continue: "CONTINUE",
  Failed: "FAILED",
};

const TaskDebugStatus = {
  JustConstructed: "JUST CONSTRUCTED",
  UncaughtError: "UNCAUGHT ERROR",
  DequeuedObsolete: "DEQUEUED (Obsolete)",
  DequeuedDependency: "DEQUEUED (Dependency Failure)",
  WaitingOnQueue: "WAITING ON QUEUE",
  WaitingToRetry: "WAITING TO RETRY",
  WaitingOnDependency: "WAITING ON DEPENDENCY",
  RunningLocal: "RUNNING LOCAL",
  ProcessingRemote: "PROCESSING REMOTE",
};

// Public: Tasks are a robust way to handle any mutating changes that need
// to interface with a remote API.
//
// Tasks help you handle and encapsulate optimistic updates, rollbacks,
// undo/redo, API responses, API errors, queuing, and multi-step
// dependencies.
//
// They are especially useful in offline mode. Users may have taken tons of
// actions that we've queued up to process when they come back online.
//
// Tasks represent individual changes to the datastore that alter the local
// cache and need to be synced back to the server.
//
// To create your own task, subclass Task and implement the following
// required methods:
//
// - {Task::performLocal}
// - {Task::performRemote}
//
// See their usage in the documentation below.
//
// ## Task Dependencies
//
// The Task system handles dependencies between multiple queued tasks. For
// example, the {SendDraftTask} has a dependency on the {SyncbackDraftTask}
// (aka saving) succeeding. To establish dependencies between tasks, your
// subclass may implement one or more of the following methods:
//
// - {Task::isDependentOnTask}
// - {Task::onDependentTaskError}
// - {Task::shouldDequeueOtherTask}
//
// ## Undo / Redo
//
// The Task system also supports undo/redo handling. Your subclass must
// implement the following methods to enable this:
//
// - {Task::isUndo}
// - {Task::canBeUndone}
// - {Task::createUndoTask}
// - {Task::createIdenticalTask}
//
// ## Offline Considerations
//
// All tasks should gracefully handle the case when there is no network
// connection.
//
// if we're offline the common behavior is for a task to:
//
// 1. Perform its local change
// 2. Attempt the remote request, which will fail
// 3. Have `performRemote` resolve a `Task.Status.Retry`
// 3. Sit queued up waiting to be retried
//
// Remember that a user may be offline for hours and perform thousands of
// tasks in the meantime. It's important that your tasks implement
// `shouldDequeueOtherTask` and `isDependentOnTask` to make sure ordering
// always remains correct.
//
// ## Serialization and Window Considerations
//
// The whole {TaskQueue} and all of its Tasks are serialized and stored in
// the Database. This allows the {TaskQueue} to work across windows and
// ensures we don't lose any pending tasks if (a user is offline for a while)
// and quits and relaunches the application.
//
// All instance variables you create must be able to be serialized to a
// JSON string and re-inflated. Notably, **`function` objects will not be
// properly re-inflated**.
//
// if (you have instance variables that are instances of core {Model})
// classes or {Task} classes, they will be automatically re-inflated to the
// correct class via {Utils::deserializeRegisteredObject}. if (you create)
// your own custom classes, they must be registered once per window via
// {TaskRegistry::register}
//
// ## Example Task
//
// **Task Definition**:
//
// ```js
// import _ from 'underscore'
// import request from 'request'
// import {Task, DatabaseStore} from 'nylas-exports'
//
// class UpdateTodoTask extends Task {
//   constructor(existingTodo, newData) {
//     super()
//     this.existingTodo = existingTodo;
//     this.newData = newData;
//   }
//
//   performLocal() {
//     this.updatedTodo = _.extend(_.clone(this.existingTodo), this.newData);
//     return DatabaseStore.inTransaction((t) => t.persistModel(this.updatedTodo));
//   }
//
//   performRemote() {
//     return new Promise (resolve, reject) => {
//       const options = {url: "https://myapi.co", method: 'PUT', json: this.newData}
//       request(options, (error, response, body) => {
//         if (error) {
//           resolve(Task.Status.Failed);
//         }
//         resolve(Task.Status.Success);
//       });
//     };
//   };
// }
// ```
//
// **Task Usage**:
//
// ```coffee
// import {Actions} from 'nylas-exports';
// import UpdateTodoTask from './update-todo-task';
//
// someMethod() {
//   ...
//   const task = new UpdateTodoTask(existingTodo, {name: "Test"});
//   Actions.queueTask(task);
//   ...
// }
// ```
//
// This example `UpdateTodoTask` does not handle undo/redo, nor does it
// rollback the changes if (there's an API error. See examples in)
// {Task::performLocal} for ideas on how to handle this.
//
export default class Task {

  static Status = TaskStatus;
  static DebugStatus = TaskDebugStatus;

  // Public: Override the constructor to pass initial args to your Task and
  // initialize instance variables.
  //
  // **IMPORTANT:** if (you override the constructor, be sure to call)
  // `super`.
  //
  // On construction, all Tasks instances are given a unique `id`.
  constructor() {
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
      debugStatus: Task.DebugStatus.JustConstructed,
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

    this.queueState.debugStatus = Task.DebugStatus.RunningLocal;
    try {
      return this.performLocal()
      .then(() => {
        this.queueState.localComplete = true;
        this.queueState.localError = null;
        this.queueState.debugStatus = Task.DebugStatus.WaitingOnQueue;
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
    this.queueState.debugStatus = Task.DebugStatus.UncaughtError;
    NylasEnv.reportError(err);
    return Promise.reject(err);
  }

  // Private: This is an internal wrapper around `performRemote`
  runRemote() {
    this.queueState.debugStatus = Task.DebugStatus.ProcessingRemote;

    if (this.queueState.localComplete === false) {
      throw new Error("runRemote called before performLocal complete, this is an assertion failure.")
    }

    if (this.queueState.remoteComplete) {
      this.queueState.status = Task.Status.Continue;
      return Promise.resolve(Task.Status.Continue);
    }

    try {
      return this.performRemote()
      .then((compositeStatus) => {
        const [status, err] = this._compositeStatus(compositeStatus);

        if (status === Task.Status.Failed) {
          // We reject here to end up on the same path as people who may
          // have manually `reject`ed the promise
          return Promise.reject(compositeStatus);
        }

        this.queueState.status = status;
        this.queueState.remoteAttempts += 1;
        this.queueState.remoteComplete = [Task.Status.Success, Task.Status.Continue].includes(status);
        this.queueState.remoteError = null;
        return Promise.resolve(status);
      })
      .catch((compositeStatus) => {
        const [status, err] = this._compositeStatus(compositeStatus);
        return this._handleRemoteError(err, status);
      })
    } catch (err) {
      return this._handleRemoteError(err);
    }
  }

  // When resolving from performRemote, people can resolve one of the
  // `Task.Status` constants. In the case of `Task.Status.Failed`, they can
  // return an array with the constant as the first item and the error
  // object as the second item. We are also resilient to accidentally
  // getting passed malformed values or error objects.
  //
  // This always returns in the form of `[status, err]`
  _compositeStatus(compositeStatus) {
    if (compositeStatus instanceof Error) {
      return [Task.Status.Failed, compositeStatus];
    }

    if (_.isString(compositeStatus)) {
      if (_.values(Task.Status).includes(compositeStatus)) {
        return [compositeStatus, null];
      }
      const err = new Error(`performRemote returned ${compositeStatus}, which is not a Task.Status`);
      return [Task.Status.Failed, err];
    }

    if (_.isArray(compositeStatus)) {
      const [status, err] = compositeStatus;
      return [status, err];
    }
    const err = new Error(`performRemote returned ${compositeStatus}, which is not a Task.Status`);
    return [Task.Status.Failed, err];
  }

  _handleRemoteError = (err, status) => {
    // Sometimes users just indicate that a task Failed, but don't provide
    // the error object
    const exitError = err || new Error(`Unspecified error in ${Task.constructor.name}.performRemote`);

    if (status !== Task.Status.Failed) {
      this.queueState.debugStatus = Task.DebugStatus.UncaughtError;
      NylasEnv.reportError(exitError);
    }

    this.queueState.status = Task.Status.Failed;
    this.queueState.remoteAttempts += 1;
    this.queueState.remoteError = exitError;

    return Promise.reject(exitError);
  }

  // -----------------------------------------------------------------------
  // -------------------------HELPER METHODS--------------------------------
  // -----------------------------------------------------------------------

  validateRequiredFields = (fields = []) => {
    for (const field of fields) {
      if (!this[field]) {
        throw new Error(`Must pass ${field}`);
      }
    }
  }

  // Most tasks that interact with a RESTful API will want to behave in a
  // similar way. We retry on temproary API error codes and permenantly
  // fail on others.
  apiErrorHandler = (err = {}) => {
    if (err instanceof APIError) {
      if (PermanentErrorCodes.includes(err.statusCode)) {
        return Promise.resolve([Task.Status.Failed, err])
      }
      return Promise.resolve(Task.Status.Retry)
    }
    return Promise.resolve([Task.Status.Failed, err]);
  }


  // -----------------------------------------------------------------------
  // -------------------------METHODS TO OBSERVE ---------------------------
  // -----------------------------------------------------------------------

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
  // {TaskQueueStatusStore::waitForPerformLocal}. Pass it the task and it
  // will return a Promise that resolves once the local action has
  // completed. This is contained in the {TaskQueueStatusStore} so you can
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

  // Public: **Required** | Put the actual API request code here.
  //
  // You must return a {Promise} that resolves to one of the following
  // status constants:
  //
  //   - `Task.Status.Success`
  //   - `Task.Status.Retry`
  //   - `Task.Status.Continue`
  //   - `Task.Status.Failed`
  //
  // The resolved status will determine what the {TaskQueue} does with this
  // task when it is finished.
  //
  // This is where you should put your actual API code. You can use the
  // node `request` library to easily hit APIs, or use the {NylasAPI} class
  // to talk to the [Nylas Platform API](https://nylas.com/cloud/docs/).
  //
  // Here is a more detailed explanation of Task Statuses:
  //
  // ### Task.Status.Success
  //
  // Resolve to `Task.Status.Success` when the task successfully completes.
  // Once done, the task will be dequeued and logged as a success.
  //
  // ### Task.Status.Retry
  //
  // if (you resolve `Task.Status.Retry`, the task will remain on the queue)
  // and tried again later. Any other task dependent on the current one
  // will also continue waiting.
  //
  // `Task.Status.Retry` is useful if (it looks like we're offline, or you)
  // get an API error code that indicates temporary failure.
  //
  // ### Task.Status.Continue
  //
  // Resolving `Task.Status.Continue` will silently dequeue the task, allow
  // dependent tasks through, but not mark it as successfully resolved.
  //
  // This is useful if (you get permanent API errors, but don't really care)
  // if (the task failed.)
  //
  // ### Task.Status.Failed
  //
  // if (you catch a permanent API error code (like a 500), or something)
  // else goes wrong then resolve to `Task.Status.Failed`.
  //
  // Resolving `Task.Status.Failed` will dequeue this task, and **dequeue
  // all dependent tasks**.
  //
  // You can optionally return the error object itself for debugging
  // purposes by resolving an array of the form: `[Task.Status.Failed,
  // errorObject]`
  //
  // You should not `throw` exceptions. Catch all cases yourself and
  // determine which `Task.Status` to resolve to. if (due to programmer)
  // error an exception is thrown, our {TaskQueue} will catch it, log it,
  // and deal with the task as if (it resolved `Task.Status.Failed`.)
  //
  // Returns a {Promise} that resolves to a valid `Task.Status` type.
  performRemote() {
    return Promise.resolve(Task.Status.Success);
  }

  // Public: determines which other tasks this one is dependent on.
  //
  // - `other` An instance of a {Task} you must test to see if (it's a)
  // dependency of this one.
  //
  // Any task that passes the truth test will be considered a "dependency".
  //
  // if (a "dependency" has a `Task.Status.Failed`, then all downstream)
  // tasks will get dequeued recursively.
  //
  // A task will also never be run at the same time as one of its
  // dependencies.
  //
  // Returns `true` (is dependent on) or `false` (is not dependent on)
  isDependentOnTask(other) {
    return false;
  }

  // Public: determines which other tasks this one should dequeue when
  // it is first queued.
  //
  // - `other` An instance of a {Task} you must test to see if (it's now)
  // obsolete.
  //
  // Any task that passes the truth test will be considered "obsolete" and
  // dequeued immediately.
  //
  // This is particularly useful in offline mode. Users may queue up tons
  // of tasks but when we come back online to process them, we only want to
  // process the latest one.
  //
  // Returns `true` (should dequeue) or `false` (should not dequeue)
  shouldDequeueOtherTask(other) {
    return false;
  }

  // Public: determines if the current task should be dequeued if one of the
  // tasks it depends on fails.
  //
  // Returns `true` (should dequeue) or `false` (should not dequeue)
  shouldBeDequeuedOnDependencyFailure() {
    return true;
  }

  onDependentTaskError(other, error) {

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
    return (new this.constructor).fromJSON(json);
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
