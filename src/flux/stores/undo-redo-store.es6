import _ from 'underscore';
import Actions from '../actions';
import NylasStore from 'nylas-store';

class UndoRedoStore extends NylasStore {

  constructor() {
    super()
    this._onQueue = this._onQueue.bind(this);
    this.undo = this.undo.bind(this);
    this.redo = this.redo.bind(this);
    this.getMostRecent = this.getMostRecent.bind(this);
    this._undo = [];
    this._redo = [];

    this.listenTo(Actions.queueTask, this._onQueue);
    this.listenTo(Actions.queueTasks, this._onQueue);

    NylasEnv.commands.add(document.body, {'core:undo': this.undo });
    NylasEnv.commands.add(document.body, {'core:redo': this.redo });
  }

  _onQueue(taskArg) {
    if (!taskArg) { return; }
    let tasks = taskArg;
    if (!(tasks instanceof Array)) { tasks = [tasks]; }
    if (tasks.length <= 0) { return; }
    const undoable = _.every(tasks, t => t.canBeUndone());
    const isRedoTask = _.every(tasks, t => t.isRedoTask);

    if (undoable) {
      if (!isRedoTask) { this._redo = []; }
      this._undo.push(tasks);
      this.trigger();
    }
  }

  undo() {
    const topTasks = this._undo.pop();
    if (!topTasks) { return; }
    this.trigger();

    for (let i = 0; i < topTasks.length; i++) {
      const task = topTasks[i];
      Actions.undoTaskId(task.id);
    }

    const redoTasks = topTasks.map((t) => {
      const redoTask = t.createIdenticalTask();
      redoTask.isRedoTask = true;
      return redoTask;
    });
    this._redo.push(redoTasks);
  }

  redo() {
    const redoTasks = this._redo.pop();
    if (!redoTasks) { return; }
    Actions.queueTasks(redoTasks);
  }

  getMostRecent() {
    for (let i = this._undo.length - 1; i >= 0; i--) {
      const allReverting = _.every(this._undo[i], t => t._isReverting);
      if (!allReverting) { return this._undo[i]; }
    }
    return []
  }

  print() {
    console.log("Undo Stack");
    console.log(this._undo);
    console.log("Redo Stack");
    return console.log(this._redo);
  }
}

export default new UndoRedoStore();
