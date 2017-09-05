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

    this.listenTo(AccountStore, () => this._onRefresh())
    this.listenTo(CategoryStore, () => this._onRefresh())
    this._onRefresh()
  }

  _onRefresh() {
    this._statesByAccount = {};

    for (const accountId of AccountStore.accountIds()) {
      const folders = CategoryStore.categories(accountId).filter(cat => cat instanceof Folder)
      const state = {};

      /*
      `localStatus` is populated by C++ mailsync. We translate it to a simpler
      representation that the JS side can rely on as the underlying
      implementation changes.
      */
      for (const folder of folders) {
        const {uidnext, syncedMinUID, busy} = folder.localStatus || {};
        state[folder.path] = {
          busy: busy !== undefined ? busy : true,
          progress: 1.0 - (syncedMinUID - 1) / uidnext,
          total: uidnext,
        }
      }

      this._statesByAccount[accountId] = state;
    }
    this._triggerDebounced();
  }

  getSyncState() {
    return this._statesByAccount;
  }

  /**
   * Returns true if Mailspring's local cache contains the entire list of available
   * folders and labels.
   *
   * This will be true if any of the available folders have started syncing,
   * since mailsync doesn't start folder sync until it has fetched the whole list
   * of folders and labels.
   */
  isCategoryListSynced(accountId) {
    const state = this._statesByAccount[accountId];
    if (!state) { return false }
    return Object.values(state).some((i) => i.progress > 0);
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
      return !state[folderPath].busy && state[folderPath].progress >= 1
    }

    const folderPaths = Object.keys(state)
    for (const aFolderPath of folderPaths) {
      const {progress, busy} = state[aFolderPath];
      if (busy || progress < 1) {
        return false;
      }
    }

    return true;
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
