import DatabaseStore from '../stores/database-store';
import Task from './task';

export default class SyncbackCategoryTask extends Task {

  constructor({category, displayName} = {}) {
    super()
    this.category = category;
    this.displayName = displayName;
  }

  label() {
    const verb = this.category.serverId ? 'Updating' : 'Creating new';
    return `${verb} ${this.category.displayType()}`;
  }

  _revertLocal() {
    return DatabaseStore.inTransaction((t) => {
      if (this.isUpdate) {
        this.category.displayName = this._initialDisplayName;
        return t.persistModel(this.category)
      }
      return t.unpersistModel(this.category)
    })
  }

  performLocal() {
    if (!this.category) {
      return Promise.reject(new Error("Attempt to call SyncbackCategoryTask.performLocal without this.category."));
    }
    this.isUpdate = !!this.category.serverId; // True if updating an existing category
    return DatabaseStore.inTransaction((t) => {
      if (this.isUpdate && this.displayName) {
        this._initialDisplayName = this.category.displayName;
        this.category.displayName = this.displayName;
      }
      return t.persistModel(this.category);
    });
  }
}
