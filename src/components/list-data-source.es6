/* eslint no-unused-vars: 0 */
import {EventEmitter} from 'events'
import ListSelection from './list-selection'

export default class ListDataSource {
  constructor() {
    this._emitter = new EventEmitter();
    this._cleanedup = false;
    this.selection = new ListSelection(this, this.trigger);
  }

  // Accessing Data

  trigger = (arg) => {
    this._emitter.emit('trigger', arg);
  }

  listen(callback, bindContext) {
    if (!(callback instanceof Function)) {
      throw new Error("ListDataSource: You must pass a function to `listen`");
    }
    if (this._cleanedup === true) {
      throw new Error("ListDataSource: You cannot listen again after removing the last listener. This is an implementation detail.");
    }

    const eventHandler = (...args) => {
      callback.apply(bindContext, args);
    }
    this._emitter.addListener('trigger', eventHandler);

    return () => {
      this._emitter.removeListener('trigger', eventHandler);
      setTimeout(() => {
        if (this._emitter.listenerCount('trigger') === 0) {
          this._cleanedup = true;
          this.cleanup();
        }
      }, 0);
    };
  }

  loaded() {
    throw new Error("ListDataSource base class does not implement loaded()");
  }

  empty() {
    throw new Error("ListDataSource base class does not implement empty()");
  }

  get(idx) {
    throw new Error("ListDataSource base class does not implement get()");
  }

  getById(id) {
    throw new Error("ListDataSource base class does not implement getById()");
  }

  indexOfId(id) {
    throw new Error("ListDataSource base class does not implement indexOfId()");
  }

  count() {
    throw new Error("ListDataSource base class does not implement count()");
  }

  itemsCurrentlyInViewMatching(matchFn) {
    throw new Error("ListDataSource base class does not implement itemsCurrentlyInViewMatching()");
  }

  setRetainedRange({start, end}) {
    throw new Error("ListDataSource base class does not implement setRetainedRange()");
  }

  cleanup() {
    this.selection.cleanup();
  }
}

class EmptyListDataSource extends ListDataSource {
  loaded() { return true }
  empty() { return true }
  get() { return null }
  getById() { return null }
  indexOfId() { return -1 }
  count() { return 0 }
  itemsCurrentlyInViewMatching() { return []; }
  setRetainedRange() { return }
}

ListDataSource.Empty = EmptyListDataSource
