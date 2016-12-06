import DatabaseStore from '../stores/database-store';
import AccountStore from '../stores/account-store';
import Task from './task';
import Actions from '../actions';
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

    const isUpdate = serverId != null
    const method = isUpdate ? "PUT" : "POST";
    const path = serverId ? `/${collection}/${serverId}` : `/${collection}`;

    return new Promise(async (resolve) => {
      try {
        const json = await new NylasAPIRequest({
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
        }).run()
        // TODO sorry
        // Previously, when we sent the request to create a folder or label to our api,
        // we would immediately get back a serverId because it was created optimistically
        // in the back end— given that K2 is strictly non-optimistic, we won’t have a serverId
        // until some undetermined time in the future, and we need to somehow reference
        // the object that /was/ optimistically created in N1 to update the ui when
        // we do get the server id.
        // Pre-assigning the id from N1 is the most simple solution to get thing working
        // correctly right now, but we’ll need to revisit this in the future for
        // other types of objects (drafts, contacts, events), and revisit how we
        // will manage optimistic updates in N1 when we merge the 2 codebases
        // with K2 (given that K2 was designed to be non-optimisitc).
        this.category.serverId = json.props.objectId || null
        if (!this.category.serverId) {
          throw new Error('SyncbackRequest for creating category did not return a serverId!')
        }
        await DatabaseStore.inTransaction((t) =>
          t.persistModel(this.category)
        );
        const unsubscribe = Actions.didReceiveSyncbackRequestDeltas.listen(async (deltas) => {
          const failed = deltas.failed.find(d => d.attributes.props.objectId === this.category.serverId)
          const succeeded = deltas.succeeded.find(d => d.attributes.props.objectId === this.category.serverId)
          if (failed) {
            unsubscribe()
            this._isReverting = true
            await this.performLocal()
            resolve(Task.Status.Failed);
          } else if (succeeded) {
            unsubscribe()
            resolve(Task.Status.Success)
          }
        })
      } catch (err) {
        if (err instanceof APIError) {
          if (!NylasAPI.PermanentErrorCodes.includes(err.statusCode)) {
            resolve(Task.Status.Retry);
          } else {
            this._isReverting = true
            await this.performLocal()
            resolve(Task.Status.Failed);
          }
        }
      }
    })
  }
}
