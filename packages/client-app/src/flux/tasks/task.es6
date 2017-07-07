/* eslint no-unused-vars: 0*/
import _ from 'underscore';
import Model from '../models/model';
import Attributes from '../attributes';
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

  static attributes = Object.assign({}, Model.attributes, {
    version: Attributes.String({
      queryable: true,
      jsonKey: 'v',
      modelKey: 'version',
    }),
    status: Attributes.String({
      queryable: true,
      modelKey: 'status',
    }),
    source: Attributes.String({
      modelKey: 'source',
    }),
    error: Attributes.Object({
      modelKey: 'error',
    }),
  });

  // Public: Override the constructor to pass initial args to your Task and
  // initialize instance variables.
  //
  // **IMPORTANT:** if (you override the constructor, be sure to call)
  // `super`.
  //
  // On construction, all Tasks instances are given a unique `id`.
  constructor(data) {
    super(data);
    this.id = this.id || generateTempId();
    this.accountId = null;
  }

  // Public: Override to raise exceptions if your task is missing required
  // arguments. This logic used to go in performLocal.
  validate() {

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
    delete json.status;
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
    return Object.assign(super.toJSON(), this);
  }

  // Private: Allows for deserialization of tasks
  fromJSON(json) {
    for (const key of Object.keys(json)) {
      this[key] = json[key];
    }
    return this;
  }

  onError(err) {
    // noop
  }

  onSuccess() {
    // noop
  }
}
