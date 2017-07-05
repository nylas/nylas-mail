import _ from 'underscore'
import NylasStore from 'nylas-store'
import AccountStore from './account-store'
import CategoryStore from './category-store'
import Folder from '../models/folder';

/**
 * FolderSyncProgressStore keeps track of the sync state per account, and will
 * trigger whenever it changes.
 *
 * The sync state for any given account has the following shape:
 *
 *   {
 *     [Gmail]/Inbox: {
 *       progress: 0.5,
 *       total: 100,
 *     }
 *     MyFunLabel: {
 *       progress: 0.2,
 *       total: 600,
 *     },
 *     ...
 *   }
 *
 */
class FolderSyncProgressStore extends NylasStore {

  constructor() {
    super()
    this._statesByAccount = {}
    this._triggerDebounced = _.debounce(this.trigger, 100)
  }

  activate() {
    this.listenTo(AccountStore, () => this._onRefresh())
    this.listenTo(CategoryStore, () => this._onRefresh())
    this._onRefresh()
  }

  _onRefresh() {
    this._statesByAccount = {};

    for (const accountId of AccountStore.accountIds()) {
      const folders = CategoryStore.categories(accountId).filter(cat => cat instanceof Folder)
      const state = {};

      for (const folder of folders) {
        const {uidnext, syncedMinUID} = folder.localStatus || {};
        state[folder.path] = {
          progress: 1.0 - (syncedMinUID - 1) / uidnext,
          total: uidnext,
        }
      }

      this._statesByAccount[accountId] = state;
    }
    this._triggerDebounced()
  }

  getSyncState() {
    return this._statesByAccount
  }

  /**
   * Returns true if N1's local cache contains the entire list of available
   * folders and labels.
   * This will be true if any of the available folders have started syncing,
   * given that K2 wont commence folder sync until it has fetched the whole list
   * of folders and labels
   */
  isCategoryListSynced(accountId) {
    const state = this._statesByAccount[accountId];
    if (!state) { return false }
    return Object.values(state).some((i) => i.progress > 0)
  }

  whenCategoryListSynced(accountId) {
    if (this.isCategoryListSynced(accountId)) {
      return Promise.resolve()
    }
    return new Promise((resolve) => {
      const unsubscribe = this.listen(() => {
        if (this.isCategoryListSynced(accountId)) {
          unsubscribe()
          resolve()
        }
      })
    })
  }

  isSyncCompleteForAccount(accountId, folderPath) {
    const state = this._statesByAccount[accountId]

    if (!state || !this.isCategoryListSynced(accountId)) {
      return false
    }

    if (folderPath) {
      return state[folderPath].progress >= 1
    }
    const folderPaths = Object.keys(state)
    for (const fname of folderPaths) {
      const syncProgress = state[fname].progress
      if (syncProgress < 1) {
        return false
      }
    }
    return true
  }

  isSyncComplete() {
    return Object.keys(this._statesByAccount).every((accountId) =>
      this.isSyncCompleteForAccount(accountId)
    );
  }

  whenSyncComplete() {
    if (this.isSyncComplete()) {
      return Promise.resolve()
    }
    return new Promise((resolve) => {
      const unsubscribe = this.listen(() => {
        if (this.isSyncComplete()) {
          unsubscribe()
          resolve()
        }
      })
    })
  }
}

export default new FolderSyncProgressStore()
