import ChangeMailTask from './change-mail-task';
import Attributes from '../attributes';
import Folder from '../models/folder';

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

  static attributes = Object.assign({}, ChangeMailTask.attributes, {
    previousFolder: Attributes.Object({
      modelKey: 'folder',
      itemClass: Folder,
    }),
    folder: Attributes.Object({
      modelKey: 'folder',
      itemClass: Folder,
    }),
  });

  constructor(data = {}) {
    if (data.folder && !(data.folder instanceof Folder)) {
      throw new Error("ChangeFolderTask: You must provide a single folder.");
    }
    if (!data.previousFolders) {
      data.previousFolders = {};
      for (const t of (data.threads || [])) {
        data.previousFolders[t.id] = t.folders.find(f => f.id !== data.folder.id) || t.folders[0];
      }
      for (const m of (data.messages || [])) {
        data.previousFolders[m.id] = m.folder;
      }
    }

    super(data);
  }

  label() {
    if (this.folder) {
      return `Moving to ${this.folder.displayName}`;
    }
    return "Moving to folder";
  }

  description() {
    if (this.taskDescription) {
      return this.taskDescription;
    }

    const folderText = ` to ${this.folder.displayName}`;

    if (this.threadIds.length > 1) {
      return `Moved ${this.threadIds.length} threads${folderText}`;
    } else if (this.messageIds.length > 1) {
      return `Moved ${this.messageIds.length} messages${folderText}`;
    }
    return `Moved${folderText}`;
  }

  validate() {
    if (!this.folder) {
      throw new Error("Must specify a `folder`");
    }
    if (this.threadIds.length > 0 && this.messageIds.length > 0) {
      throw new Error("ChangeFolderTask: You can move `threads` or `messages` but not both")
    }
    if (this.threadIds.length === 0 && this.messageIds.length === 0) {
      throw new Error("ChangeFolderTask: You must provide a `threads` or `messages` Array of models or IDs.")
    }

    super.validate();
  }

  _isArchive() {
    return this.folder.name === "archive" || this.folder.name === "all"
  }

  createUndoTask() {
    const task = super.createUndoTask();
    const {folder, previousFolder} = task;
    task.folder = previousFolder;
    task.previousFolder = folder;
    return task;
  }
}
