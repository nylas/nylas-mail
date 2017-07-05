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
 * {
 *   folderSyncProgress: {
 *     inbox: {
 *       progress: 0.5,
 *       total: 100,
 *     }
 *     archive: {
 *       progress: 0.2,
 *       total: 600,
 *     },
 *     ...
 *   }
 * }
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
    const accountIds = AccountStore.accountIds();

    this._statesByAccount = {};

    for (const accountId of accountIds) {
      const folders = CategoryStore.categories(accountId).filter(cat => cat instanceof Folder)
      const folderSyncProgress = {};

      for (const folder of folders) {
        const name = folder.name || folder.displayName;
        const {uidnext, syncedMinUID} = folder.localStatus || {};
        folderSyncProgress[name] = {
          progress: 1.0 - (syncedMinUID - 1) / uidnext,
          total: uidnext,
        }
      }

      this._statesByAccount[accountId] = {folderSyncProgress};
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
    const state = this._statesByAccount[accountId]
    if (!state) { return false }
    const folderNames = Object.keys(state.folderSyncProgress || {})
    if (folderNames.length === 0) { return false }
    return folderNames.some((fname) => state.folderSyncProgress[fname].progress !== 0)
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

  isSyncCompleteForAccount(accountId, folderName) {
    const state = this._statesByAccount[accountId]
    if (!state) { return false }

    if (!this.isCategoryListSynced(accountId)) {
      return false
    }

    if (folderName) {
      return state.folderSyncProgress[folderName].progress >= 1
    }
    const folderNames = Object.keys(state.folderSyncProgress)
    for (const fname of folderNames) {
      const syncProgress = state.folderSyncProgress[fname].progress
      if (syncProgress < 1) {
        return false
      }
    }
    return true
  }

  isSyncComplete() {
    const accountIds = Object.keys(this._statesByAccount)
    if (accountIds.length === 0) { return false }
    for (const accountId of accountIds) {
      if (!this.isSyncCompleteForAccount(accountId)) {
        return false
      }
    }
    return true
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
