import DatabaseStore from '../stores/database-store';
import AccountStore from '../stores/account-store';
import Task from './task';
import NylasAPI from '../nylas-api';
import NylasAPIRequest from '../nylas-api-request';
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
    if (!this.category) {
      return Promise.reject(new Error("Attempt to call SyncbackCategoryTask.performLocal without this.category."));
    }

    const isUpdating = this.category.serverId;

    return DatabaseStore.inTransaction((t) => {
      if (this._isReverting) {
        if (isUpdating) {
          this.category.displayName = this._initialDisplayName;
          t.persistModel(this.category);
        } else {
          t.unpersistModel(this.category);
        }
      } else {
        if (isUpdating && this.displayName) {
          this._initialDisplayName = this.category.displayName;
          this.category.displayName = this.displayName;
        }
        t.persistModel(this.category);
      }
    });
  }

  performRemote() {
    const {serverId, accountId, displayName} = this.category;
    const account = AccountStore.accountForId(accountId);
    const collection = account.usesLabels() ? "labels" : "folders";

    const method = serverId ? "PUT" : "POST";
    const path = serverId ? `/${collection}/${serverId}` : `/${collection}`;

    return new NylasAPIRequest({
      api: NylasAPI,
      options: {
        path,
        method,
        accountId,
        body: {
          display_name: displayName,
        },
        // returnsModel must be false because we want to update the
        // existing model rather than returning a new model.
        returnsModel: false,
      },
    })
    .run()
    .then((json) => {
      // This is where we update the existing model with the newly
      // created serverId.
      this.category.serverId = json.id;
      return DatabaseStore.inTransaction((t) =>
        t.persistModel(this.category)
      );
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
