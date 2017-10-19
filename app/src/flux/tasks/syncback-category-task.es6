import utf7 from 'utf7';
import Task from './task';
import Attributes from '../attributes';

export default class SyncbackCategoryTask extends Task {
  static attributes = Object.assign({}, Task.attributes, {
    path: Attributes.String({
      modelKey: 'path',
    }),
    existingPath: Attributes.String({
      modelKey: 'existingPath',
    }),
    created: Attributes.Object({
      modelKey: 'created',
    }),
  });

  static forCreating({ name, accountId }) {
    return new SyncbackCategoryTask({
      path: utf7.imap.encode(name),
      accountId: accountId,
    });
  }

  static forRenaming({ path, accountId, newName }) {
    return new SyncbackCategoryTask({
      existingPath: path,
      path: utf7.imap.encode(newName),
      accountId: accountId,
    });
  }

  label() {
    const verb = this.category.serverId ? 'Updating' : 'Creating new';
    return `${verb} ${this.category.displayType()}`;
  }
}
