import Task from './task';

export default class DestroyCategoryTask extends Task {

  constructor({path, accountId} = {}) {
    super();
    this.path = path;
    this.accountId = accountId;
  }

  label() {
    return `Deleting ${this.category.displayType()} ${this.category.displayName}`
  }
}
