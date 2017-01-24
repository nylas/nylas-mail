import DatabaseStore from '../stores/database-store';
import AccountStore from '../stores/account-store';
import Task from './task';
import NylasAPI from '../nylas-api';
import SyncbackTaskAPIRequest from '../syncback-task-api-request';
import {APIError} from '../errors';

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

  performRemote() {
    if (!this.category) {
      return Promise.reject(new Error("Attempted to call SyncbackCategoryTask.performRemote without this.category."));
    }
    const {serverId, accountId} = this.category;
    const account = AccountStore.accountForId(accountId);
    const collection = account.usesLabels() ? "labels" : "folders";

    const method = serverId ? "PUT" : "POST";
    const path = serverId ? `/${collection}/${serverId}` : `/${collection}`;

    let runPromise = Promise.resolve();

    if (this._syncbackRequestId) {
      runPromise = SyncbackTaskAPIRequest.waitForQueuedRequest(this._syncbackRequestId)
    } else {
      runPromise = new SyncbackTaskAPIRequest({
        api: NylasAPI,
        options: {
          path,
          method,
          accountId,
          body: {
            display_name: this.displayName || this.category.displayName,
          },
          // returnsModel must be false because we want to update the
          // existing model rather than returning a new model.
          returnsModel: false,
          onSyncbackRequestCreated: (syncbackRequest) => {
            this._syncbackRequestId = syncbackRequest.id
          },
        },
      }).run()
    }

    return runPromise.then((responseJSON) => {
      this.category.serverId = responseJSON.id
      if (!this.category.serverId) {
        throw new Error('SyncbackRequest for creating category did not return a serverId!')
      }
      return DatabaseStore.inTransaction(t => t.persistModel(this.category))
    })
    .thenReturn(Task.Status.Success)
    .catch(APIError, async (err) => {
      if (!NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
        return Task.Status.Retry;
      }
      await this._revertLocal()
      try {
        if (/command argument error/gi.test(err.message)) {
          const action = this.isUpdate ? 'update' : 'create';
          const type = this.category.displayType();
          NylasEnv.showErrorDialog(`Could not ${action} ${type}. Your mail provider has placed restrictions on this ${type}.`);
        }
      } catch (e) {
        // If notifying the user fails, just move on and mark the task as failed.
      }
      return Task.Status.Failed;
    })
  }
}
