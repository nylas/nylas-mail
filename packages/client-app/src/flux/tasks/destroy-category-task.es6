import DatabaseStore from '../stores/database-store';
import Task from './task';
import ChangeFolderTask from './change-folder-task';
import ChangeLabelTask from './change-labels-task';
import SyncbackCategoryTask from './syncback-category-task';

export default class DestroyCategoryTask extends Task {

  constructor({category} = {}) {
    super();
    this.category = category;
  }

  label() {
    return `Deleting ${this.category.displayType()} ${this.category.displayName}`
  }

  isDependentOnTask(other) {
    return (other instanceof ChangeFolderTask) ||
           (other instanceof ChangeLabelTask) ||
           (other instanceof SyncbackCategoryTask)
  }

  performLocal() {
    if (!this.category) {
      return Promise.reject(new Error("Attempt to call DestroyCategoryTask.performLocal without this.category."));
    }

    return DatabaseStore.inTransaction((t) =>
      t.unpersistModel(this.category)
    );
  }
}
