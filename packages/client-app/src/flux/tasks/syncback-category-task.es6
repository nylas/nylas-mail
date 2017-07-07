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

  constructor({existingPath, path, accountId, ...rest} = {}) {
    super(rest);
    this.existingPath = existingPath;
    this.path = path;
    this.accountId = accountId;
  }

  label() {
    const verb = this.category.serverId ? 'Updating' : 'Creating new';
    return `${verb} ${this.category.displayType()}`;
  }
}
