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
    if (!this.category) {
      return Promise.reject(new Error("Attempt to call SyncbackCategoryTask.performLocal without this.category."));
    }

    const isUpdating = this.category.serverId;

    return DatabaseStore.inTransaction((t) => {
      if (this._isReverting) {
        if (isUpdating) {
          this.category.displayName = this._initialDisplayName;
          return t.persistModel(this.category);
        }
        return t.unpersistModel(this.category);
      }
      if (isUpdating && this.displayName) {
        this._initialDisplayName = this.category.displayName;
        this.category.displayName = this.displayName;
      }
      return t.persistModel(this.category);
    });
  }

  performRemote() {
    const {serverId, accountId, displayName} = this.category;
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
          display_name: displayName,
        },
        // returnsModel must be false because we want to update the
        // existing model rather than returning a new model.
        returnsModel: false,
        onSyncbackRequestCreated: (json) => {
          // TODO
          // Previously, when we sent the request to create a folder or label to our api,
          // we would immediately get back a serverId because it was created optimistically
          // in the back end. Given that K2 is strictly non-optimistic, we won’t have a serverId
          // until some undetermined time in the future.
          //
          // For now, the simplest solution is for the created syncback request to
          // include the id of the category that will eventually be created
          // (given that ids are generated deterministically).
          // We’ll need to revisit this in the future for other types of objects
          // (drafts, contacts, events), and revisit how we will manage optimistic
          // updates in N1 when we merge the 2 codebases with K2
          this.category.serverId = json.props.objectId || null
          if (!this.category.serverId) {
            throw new Error('SyncbackRequest for creating category did not return a serverId!')
          }
          return DatabaseStore.inTransaction(t => t.persistModel(this.category))
        },
      },
    })
    .run()
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
