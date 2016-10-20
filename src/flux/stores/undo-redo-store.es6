import _ from 'underscore';
import NylasStore from 'nylas-store';

import Actions from '../actions';

class UndoRedoStore extends NylasStore {

  constructor() {
    super()
    this._undo = [];
    this._redo = [];

    this._mostRecentTasks = [];

    this.listenTo(Actions.queueTask, this._onQueue);
    this.listenTo(Actions.queueTasks, this._onQueue);

    NylasEnv.commands.add(document.body, {'core:undo': this.undo });
    NylasEnv.commands.add(document.body, {'core:redo': this.redo });
  }

  _onQueue = (taskArg) => {
    if (!taskArg) { return; }
    let tasks = taskArg;
    if (!(tasks instanceof Array)) { tasks = [tasks]; }
    if (tasks.length <= 0) { return; }
    const undoable = _.every(tasks, t => t.canBeUndone());
    const isRedoTask = _.every(tasks, t => t.isRedoTask);

    if (undoable) {
      if (!isRedoTask) { this._redo = []; }
      this._undo.push(tasks);
      this._mostRecentTasks = tasks;
      this.trigger();
    }
  }

  undo = () => {
    const topTasks = this._undo.pop();
    if (!topTasks) { return; }

    this._mostRecentTasks = [];
    this.trigger();

    for (const task of topTasks) {
      Actions.undoTaskId(task.id);
    }

    const redoTasks = topTasks.map((t) => {
      const redoTask = t.createIdenticalTask();
      redoTask.isRedoTask = true;
      return redoTask;
    });
    this._redo.push(redoTasks);
  }

  redo = () => {
    const redoTasks = this._redo.pop();
    if (!redoTasks) { return; }
    Actions.queueTasks(redoTasks);
  }

  getMostRecent = () => {
    return this._mostRecentTasks;
  }

  print() {
    console.log("Undo Stack");
    console.log(this._undo);
    console.log("Redo Stack");
    console.log(this._redo);
  }
}

export default new UndoRedoStore();
