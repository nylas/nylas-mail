import Task from './task';
import Folder from '../models/folder';
import Attributes from '../attributes';

export default class ExpungeAllInFolderTask extends Task {
  static attributes = Object.assign({}, Task.attributes, {
    folder: Attributes.Object({
      modelKey: 'folder',
      itemClass: Folder,
    }),
  });

  label() {
    return `Deleting all messages in ${this.folder ? this.folder.displayName() : 'unknown'}`;
  }
}
