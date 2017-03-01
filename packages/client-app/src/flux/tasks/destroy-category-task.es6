import DatabaseStore from '../stores/database-store';
import AccountStore from '../stores/account-store';
import Task from './task';
import Category from '../models/category';
import ChangeFolderTask from './change-folder-task';
import ChangeLabelTask from './change-labels-task';
import SyncbackCategoryTask from './syncback-category-task';
import NylasAPI from '../nylas-api';
import SyncbackTaskAPIRequest from '../syncback-task-api-request';
import {APIError} from '../errors';

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

  performRemote() {
    if (!this.category) {
      return Promise.reject(new Error("Attempt to call DestroyCategoryTask.performRemote without this.category."));
    }
    if (!this.category.serverId) {
      return Promise.reject(new Error("Attempt to call DestroyCategoryTask.performRemote without this.category.serverId."));
    }

    const {serverId, accountId} = this.category;
    const account = AccountStore.accountForId(accountId);
    const path = account.usesLabels() ? `/labels/${serverId}` : `/folders/${serverId}`;

    // We need to lock this model here to prevent it from beifly showing up
    // on the modify delta and then correctly disappearing on the delete
    // delta which comes after a delay
    NylasAPI.incrementRemoteChangeLock(Category, this.category.serverId);

    let runPromise = Promise.resolve();

    if (this._syncbackRequestId) {
      runPromise = SyncbackTaskAPIRequest.waitForQueuedRequest(this._syncbackRequestId)
    } else {
      runPromise = new SyncbackTaskAPIRequest({
        api: NylasAPI,
        options: {
          accountId,
          path,
          method: 'DELETE',
          onSyncbackRequestCreated: (syncbackRequest) => {
            this._syncbackRequestId = syncbackRequest.id
          },
        },
      }).run()
    }

    return runPromise.thenReturn(Task.Status.Success)
    .catch(APIError, (err) => {
      if (!NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
        return Promise.resolve(Task.Status.Retry);
      }
      NylasAPI.decrementRemoteChangeLock(Category, this.category.serverId);
      return DatabaseStore.inTransaction((t) =>
        t.persistModel(this.category)
      ).then(() => {
        NylasEnv.reportError(
          new Error(`Deleting category responded with ${err.statusCode}!`)
        );
        this._notifyUserOfError(this.category, err);
        return Promise.resolve(Task.Status.Failed);
      });
    })
  }

  _notifyUserOfError(category, err) {
    const displayName = category.displayName;
    const displayType = category.displayType();

    let msg = `The ${displayType} ${displayName} could not be deleted.`;
    if (displayType === 'folder') {
      msg += " Make sure the folder you want to delete is empty before deleting it.";
    }

    NylasEnv.showErrorDialog(msg, {detail: JSON.stringify(err)});
  }
}
