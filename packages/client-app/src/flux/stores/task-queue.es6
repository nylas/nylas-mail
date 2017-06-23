import _ from 'underscore';
import NylasStore from 'nylas-store';
import {Rx} from 'nylas-exports';
import Task from "../tasks/task";
import DatabaseObjectRegistry from '../../registries/database-object-registry';
import Actions from '../actions';
import DatabaseStore from './database-store';

/**
Public: The TaskQueue is a Flux-compatible Store that manages a queue of {Task}
objects. Each {Task} represents an individual API action, like sending a draft
or marking a thread as "read". Tasks optimistically make changes to the app's
local cache and encapsulate logic for performing changes on the server, rolling
back in case of failure, and waiting on dependent tasks.

The TaskQueue is essential to offline mode in N1. It automatically pauses
when the user's internet connection is unavailable and resumes when online.

The task queue is persisted to disk, ensuring that tasks are executed later,
even if the user quits N1.

The TaskQueue is only available in the app's main window. Rather than directly
queuing tasks, you should use the {Actions} to interact with the {TaskQueue}.
Tasks queued from secondary windows are serialized and sent to the application's
main window via IPC.

## Queueing a Task

```coffee
if @_thread && @_thread.unread
  Actions.queueTask(new ChangeStarredTask(thread: @_thread, starred: true))
```

## Dequeueing a Task

```coffee
Actions.dequeueMatchingTask({
  type: 'DestroyCategoryTask',
  matching: {
    categoryId: 'bla'
  }
})
*/
class TaskQueue extends NylasStore {
  constructor() {
    super();
    this._queue = [];
    this._completed = [];
    this._currentSequentialId = Date.now();

    this._waitingForLocal = [];
    this._waitingForRemote = [];

    Rx.Observable.fromQuery(DatabaseStore.findAll(Task)).subscribe((tasks => {
      this._queue = tasks.filter(t => t.complete === false);
      this._completed = tasks.filter(t => t.complete === true);
      this.trigger();
      // TODO : this._waitingForLocal!
    }))

    this.listenTo(Actions.queueTask, this.enqueue)
    this.listenTo(Actions.queueTasks, (tasks) => {
      if (!tasks || !tasks.length) { return; }
      for (const task of tasks) { this.enqueue(task); }
    });
    this.listenTo(Actions.undoTaskId, this.enqueueUndoOfTaskId);
    this.listenTo(Actions.dequeueTask, this.dequeue);
  }

  queue() {
    return this._queue;
  }

  completed() {
    return this._completed;
  }

  allTasks() {
    return [].concat(this._queue, this._completed);
  }

  /*
  Public: Returns an existing task in the queue that matches the type you provide,
  and any other match properties. Useful for checking to see if something, like
  a "SendDraft" task is in-flight.

  - `type`: The string name of the task class, or the Task class itself. (ie:
    {SaveDraftTask} or 'SaveDraftTask')

  - `matching`: Optional An {Object} with criteria to pass to _.isMatch. For a
     SaveDraftTask, this could be {draftClientId: "123123"}

  Returns a matching {Task}, or null.
  */
  findTask(type, matching = {}) {
    this.findTasks(type, matching).unshift();
  }

  findTasks(typeOrClass, matching = {}, {includeCompleted} = {}) {
    const type = typeOrClass instanceof String ? typeOrClass : typeOrClass.name;
    const tasks = includeCompleted ? [].concat(this._queue, this._completed) : this._queue;

    const matches = tasks.filter((task) => {
      if (task.constructor.name !== type) { return false; }
      if (matching instanceof Function) {
        return matching(task);
      }
      return _.isMatch(task, matching);
    });

    return matches;
  }

  enqueue = (task) => {
    if (!(task instanceof Task)) {
      console.log(task);
      throw new Error("You must queue a `Task` instance. Be sure you have the task registered with the DatabaseObjectRegistry. If this is a task for a custom plugin, you must export a `taskConstructors` array with your `Task` constructors in it. You must all subclass the base Nylas `Task`.");
    }
    if (!DatabaseObjectRegistry.isInRegistry(task.constructor.name)) {
      console.log(task);
      throw new Error("You must queue a `Task` instance which is registred with the DatabaseObjectRegistry")
    }
    if (!task.id) {
      console.log(task);
      throw new Error("Tasks must have an ID prior to being queued. Check that your Task constructor is calling `super`");
    }
    task.sequentialId = ++this._currentSequentialId;
    task.status = 'local';

    NylasEnv.actionBridgeCpp.onTellClients({type: 'task-queued', task: task});
  }

  enqueueUndoOfTaskId = (taskId) => {
    const task = this._queue.find(t => t.id === taskId) || this._completed.find(t => t.id === taskId);
    if (task) {
      this.enqueue(task.createUndoTask());
    }
  }

  dequeue = (taskOrId) => {
    const task = this._resolveTaskArgument(taskOrId);
    if (!task) {
      throw new Error("Couldn't find task in queue to dequeue");
    }

    if (task.queueState.isProcessing) {
      // We cannot remove a task from the queue while it's running and pretend
      // things have stopped. Ask the task to cancel. It's promise will resolve
      // or reject, and then we'll end up back here.
      task.cancel();
    } else {
      DatabaseStore.inTransaction((t) => {
        return t.unpersistModel(task);
      });
    }
  };

  waitForPerformLocal = (task) => {
    return new Promise((resolve) => {
      this._waitingForLocal.push({task, resolve});
    });
  }

  waitForPerformLocal = (task) => {
    return new Promise((resolve) => {
      this._waitingForRemote.push({task, resolve});
    });
  }

  // Helper Methods

  _resolveTaskArgument(taskOrId) {
    if (!taskOrId) {
      return null;
    }
    if (taskOrId instanceof Task) {
      return this._queue.find(task => task === taskOrId);
    }
    return this._queue.find(t => t.id === taskOrId);
  }
}

export default new TaskQueue();
