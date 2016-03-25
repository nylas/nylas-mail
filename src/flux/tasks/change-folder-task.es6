import _ from 'underscore';
import Thread from '../models/thread';
import Category from '../models/category';
import Message from '../models/message';
import DatabaseStore from '../stores/database-store';
import ChangeMailTask from './change-mail-task';
import SyncbackCategoryTask from './syncback-category-task';

// Public: Create a new task to apply labels to a message or thread.
//
// Takes an options object of the form:
//   - folder: The {Folder} or {Folder} IDs to move to
//   - threads: An array of {Thread}s or {Thread} IDs
//   - threads: An array of {Message}s or {Message} IDs
//   - undoData: Since changing the folder is a destructive action,
//   undo tasks need to store the configuration of what folders messages
//   were in. When creating an undo task, we fill this parameter with
//   that configuration
//
export default class ChangeFolderTask extends ChangeMailTask {

  constructor(options = {}) {
    super(options);
    this.taskDescription = options.taskDescription;
    this.folder = options.folder;
  }

  label() {
    if (this.folder) {
      return `Moving to ${this.folder.displayName}…`;
    }
    return "Moving to folder…";
  }

  categoriesToAdd() {
    return [this.folder];
  }

  description() {
    if (this.taskDescription) {
      return this.taskDescription;
    }

    let folderText = "";
    if (this.folder instanceof Category) {
      folderText = ` to ${this.folder.displayName}`;
    }

    if (this.threads.length > 0) {
      if (this.threads.length > 1) {
        return `Moved ${this.threads.length} threads${folderText}`;
      }
      return `Moved 1 thread${folderText}`;
    }
    if (this.messages.length > 0) {
      if (this.messages.length > 1) {
        return `Moved ${this.messages.length} messages${folderText}`;
      }
      return `Moved 1 message${folderText}`;
    }
    return `Moved objects${folderText}`;
  }

  isDependentOnTask(other) {
    return (other instanceof SyncbackCategoryTask);
  }

  performLocal() {
    if (!this.folder) {
      return Promise.reject(new Error("Must specify a `folder`"))
    }
    if (this.threads.length > 0 && this.messages.length > 0) {
      return Promise.reject(new Error("ChangeFolderTask: You can move `threads` or `messages` but not both"))
    }
    if (this.threads.length === 0 && this.messages.length === 0) {
      return Promise.reject(new Error("ChangeFolderTask: You must provide a `threads` or `messages` Array of models or IDs."))
    }

    // Convert arrays of IDs or models to models.
    // modelify returns immediately if (no work is required)
    return Promise.props({
      folder: DatabaseStore.modelify(Category, [this.folder]),
      threads: DatabaseStore.modelify(Thread, this.threads),
      messages: DatabaseStore.modelify(Message, this.messages),

    }).then(({folder, threads, messages}) => {
      // Remove any objects we weren't able to find. This can happen pretty easily
      // if (you undo an action && other things have happened.)
      this.folder = folder[0];
      this.threads = _.compact(threads);
      this.messages = _.compact(messages);

      if (!this.folder) {
        return Promise.reject(new Error("The specified folder could not be found."));
      }

      // The base class does the heavy lifting and calls changesToModel
      return super.performLocal();
    });
  }

  processNestedMessages() {
    return false;
  }

  changesToModel(model) {
    if (model instanceof Thread) {
      return {categories: [this.folder]}
    }
    if (model instanceof Message) {
      return {categories: [this.folder]}
    }
    return null;
  }

  requestBodyForModel(model) {
    if (model instanceof Thread) {
      return {folder: model.folders[0] ? model.folders[0].id : null};
    }
    if (model instanceof Message) {
      return {folder: model.folder ? model.folder.id : null};
    }
  }
}
