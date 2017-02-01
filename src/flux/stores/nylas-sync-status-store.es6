import _ from 'underscore'
import Rx from 'rx-lite'
import NylasStore from 'nylas-store'
import AccountStore from './account-store'
import DatabaseStore from './database-store'
import CategoryStore from './category-store'


/**
 * NylasSyncStatusStore keeps track of the sync state per account, and will
 * trigger whenever it changes.
 *
 * The sync state for any given account has the following shape:
 *
 * {
 *   deltaCursors: {
 *     localSync,
 *     n1Cloud,
 *   },
 *   deltaStatus: {
 *     localSync,
 *     n1Cloud,
 *   },
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
class NylasSyncStatusStore extends NylasStore {

  constructor() {
    super()
    this._statesByAccount = {}
    this._accountSubscriptions = new Map()
    this._triggerDebounced = _.debounce(this.trigger, 100)

    this.listenTo(AccountStore, () => this._onAccountsChanged())
    this.listenTo(CategoryStore, () => this._onCategoriesChanged())

    this._onCategoriesChanged()
    this._setupAccountSubscriptions(AccountStore.accountIds())
  }

  _setupAccountSubscriptions(accountIds) {
    accountIds.forEach((accountId) => {
      if (this._accountSubscriptions.has(accountId)) { return; }
      const query = DatabaseStore.findJSONBlob(`NylasSyncWorker:${accountId}`)
      const sub = Rx.Observable.fromQuery(query)
      .subscribe((json) => this._updateState(accountId, json))
      this._accountSubscriptions.set(accountId, sub)
    })
  }

  _onAccountsChanged() {
    const currentIds = Array.from(this._accountSubscriptions.keys())
    const nextIds = AccountStore.accountIds()
    const newIds = _.difference(nextIds, currentIds)
    const removedIds = _.difference(currentIds, nextIds)

    removedIds.forEach((accountId) => {
      if (this._accountSubscriptions.has(accountId)) {
        this._accountSubscriptions.get(accountId).dispose()
      }

      if (this._statesByAccount[accountId]) {
        delete this._statesByAccount[accountId]
        this._triggerDebounced()
      }
    })
    this._setupAccountSubscriptions(newIds)
  }

  _onCategoriesChanged() {
    const accountIds = AccountStore.accountIds()
    for (const accountId of accountIds) {
      const folders = CategoryStore.categories(accountId)
      .filter(cat => cat.object === 'folder')

      const updates = {}
      for (const folder of folders) {
        const name = folder.name || folder.displayName
        const {approxPercentComplete, approxTotal, oldestProcessedDate} = folder.syncProgress || {};
        updates[name] = {
          progress: approxPercentComplete || 0,
          total: approxTotal || 0,
          oldestProcessedDate: oldestProcessedDate ? new Date(oldestProcessedDate) : new Date(),
        }
      }
      this._updateState(accountId, {folderSyncProgress: updates})
    }
  }

  _updateState(accountId, updates) {
    const currentState = this._statesByAccount[accountId] || {}
    const nextState = {
      ...currentState,
      ...updates,
    }
    if (_.isEqual(currentState, nextState)) { return }
    this._statesByAccount[accountId] = nextState
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

  busy() {
    return !this.isSyncComplete()
  }

  /**
   * @return true if the N1Cloud delta stream is connected for at least one
   * account
   */
  connected() {
    const statuses = Object.keys(this._statesByAccount)
    .map((accountId) => this._statesByAccount[accountId].deltaStatus)
    .filter((deltaStatus) => deltaStatus != null)

    if (statuses.length === 0) {
      return true
    }

    return statuses.some((status) => status.n1Cloud !== 'closed')
  }
}

export default new NylasSyncStatusStore()
