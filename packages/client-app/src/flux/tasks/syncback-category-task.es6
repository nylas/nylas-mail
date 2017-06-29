import Task from './task';

export default class SyncbackCategoryTask extends Task {

  constructor({existingPath, path, accountId} = {}) {
    super()
    this.existingPath = existingPath;
    this.path = path;
    this.accountId = accountId;
    this.created = null;
  }

  label() {
    const verb = this.category.serverId ? 'Updating' : 'Creating new';
    return `${verb} ${this.category.displayType()}`;
  }
}
