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
    return `${verb} ${this.category.displayType()}...`;
  }

  performLocal() {
    // This operation is non-optimistic! Don't do anything.
    return Promise.resolve();
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

    return new SyncbackTaskAPIRequest({
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
      },
    })
    .run()
    .then((responseJSON) => {
      if (serverId) { return null; }
      this.category.serverId = responseJSON.categoryServerId
      if (!this.category.serverId) {
        throw new Error('SyncbackRequest for creating category did not return a serverId!')
      }
      return DatabaseStore.inTransaction(t => t.persistModel(this.category))
    })
    .thenReturn(Task.Status.Success)
    .catch(APIError, (err) => {
      if (!NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
        return Promise.resolve(Task.Status.Retry);
      }
      this._isReverting = true;
      return this.performLocal().thenReturn(Task.Status.Failed);
    })
  }
}
