import NylasStore from 'nylas-store';
import Actions from '../actions';

const TASK_SOURCE_REDO = 'redo';

class UndoRedoStore extends NylasStore {
  constructor() {
    super();
    this._undo = [];
    this._redo = [];

    this._mostRecentTasks = [];

    this.listenTo(Actions.queueTask, this._onQueue);
    this.listenTo(Actions.queueTasks, this._onQueue);

    AppEnv.commands.add(document.body, { 'core:undo': this.undo });
    AppEnv.commands.add(document.body, { 'core:redo': this.redo });
  }

  _onQueue = taskOrTasks => {
    const tasks = taskOrTasks instanceof Array ? taskOrTasks : [taskOrTasks];
    if (tasks.length === 0) {
      return;
    }

    const isUndoableAndNotUndo = tasks.every(t => t.canBeUndone && !t.isUndo);
    const isRedo = tasks.every(t => t.source === TASK_SOURCE_REDO);

    if (isUndoableAndNotUndo) {
      if (!isRedo) {
        this._redo = [];
      }
      this._undo.push(tasks);
      this._mostRecentTasks = tasks;
      this.trigger();
    }
  };

  undo = () => {
    const topTasks = this._undo.pop();
    if (!topTasks) {
      return;
    }

    this._mostRecentTasks = [];
    this.trigger();

    for (const task of topTasks) {
      Actions.queueTask(task.createUndoTask());
    }

    const redoTasks = topTasks.map(t => {
      const redoTask = t.createIdenticalTask();
      redoTask.source = TASK_SOURCE_REDO;
      return redoTask;
    });
    this._redo.push(redoTasks);
  };

  redo = () => {
    const redoTasks = this._redo.pop();
    if (!redoTasks) {
      return;
    }
    Actions.queueTasks(redoTasks);
  };

  getMostRecent = () => {
    return this._mostRecentTasks;
  };

  print() {
    console.log('Undo Stack');
    console.log(this._undo);
    console.log('Redo Stack');
    console.log(this._redo);
  }
}

export default new UndoRedoStore();
