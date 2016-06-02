import _ from 'underscore';

export default class UndoStack {
  constructor(options) {
    this._options = options;
    this._stack = []
    this._redoStack = []
    this._MAX_STACK_SIZE = 1000
    this._accumulated = {};
  }

  current() {
    return _.last(this._stack) || null;
  }

  undo() {
    if (this._stack.length <= 1) { return null; }
    const item = this._stack.pop();
    this._redoStack.push(item);
    return this.current();
  }

  redo() {
    const item = this._redoStack.pop();
    if (!item) { return null; }
    this._stack.push(item);
    return this.current();
  }

  accumulate = (state) => {
    Object.assign(this._accumulated, state);
    const shouldSnapshot = this._options.shouldSnapshot && this._options.shouldSnapshot(this.current(), this._accumulated);
    if (!this.current() || shouldSnapshot) {
      this.save(this._accumulated);
      this._accumulated = {};
    }
  }

  save = (historyItem) => {
    if (_.isEqual(this.current(), historyItem)) {
      return;
    }

    this._redoStack = [];
    this._stack.push(historyItem);
    while (this._stack.length > this._MAX_STACK_SIZE) {
      this._stack.shift();
    }
  }

  saveAndUndo = (currentItem) => {
    const top = this._stack.length - 1;
    const snapshot = this._stack[top];
    if (!snapshot) {
      return null;
    }
    this._stack[top] = currentItem;
    this.undo();

    return snapshot;
  }
}
