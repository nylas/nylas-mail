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
 *     inbox: 0.5,
 *     archive: 0.2,
 *     ...
 *   }
 * }
 *
 */
class NylasSyncStatusStore extends NylasStore {

  constructor() {
    super()
    this._statesByAccount = {}
    this._subscriptions = new Map()

    this.listenTo(AccountStore, () => this._onAccountsChanged())
    this.listenTo(CategoryStore, () => this._onCategoriesChanged())

    this._triggerDebounced = _.debounce(this.trigger, 100)
    this._setupSubscriptions(AccountStore.accountIds())
  }

  _setupSubscriptions(accountIds) {
    accountIds.forEach((accountId) => {
      if (this._subscriptions.has(accountId)) { return; }
      const query = DatabaseStore.findJSONBlob(`NylasSyncWorker:${accountId}`)
      const sub = Rx.Observable.fromQuery(query)
      .subscribe((json) => this._updateState(accountId, json))
      this._subscriptions.set(accountId, sub)
    })
  }

  _onAccountsChanged() {
    const currentIds = Array.from(this.subscriptions.keys())
    const nextIds = AccountStore.accountIds()
    const newIds = _.difference(nextIds, currentIds)
    const removedIds = _.difference(currentIds, nextIds)

    removedIds.forEach((accountId) => {
      if (this._subscriptions.has(accountId)) {
        this._subscriptions.get(accountId).dispose()
      }

      if (this._statesByAccount[accountId]) {
        delete this._statesByAccount[accountId]
        this._triggerDebounced()
      }
    })
    this._setupSubscriptions(newIds)
  }

  _onCategoriesChanged() {
    const accountIds = Object.keys(this._statesByAccount)
    for (const accountId of accountIds) {
      const folders = CategoryStore.categories(accountId)
      .filter(cat => cat.object === 'folder')

      const updates = {}
      for (const folder of folders) {
        const name = folder.name || folder.displayName
        const {uidnext, fetchedmin, fetchedmax} = folder.syncState || {}
        if (uidnext) {
          const progress = (+fetchedmax - +fetchedmin + 1) / uidnext
          updates[name] = progress
        } else {
          // We don't have a uidnext if the sync hasn't started at all,
          // but we've found the folder.
          updates[name] = 0
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

  state() {
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
    return folderNames.some((name) => state.folderSyncProgress[name] !== 0)
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
      return state.folderSyncProgress[folderName] >= 1
    }
    const folderNames = Object.keys(state.folderSyncProgress)
    for (const fname of folderNames) {
      const syncProgress = state.folderSyncProgress[fname]
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
    Return true if any account is in a state other than `retrying`.
    When data isn't received, NylasLongConnection closes the socket and
    goes into `retrying` state.
  */
  connected() {
    const statuses = Object.keys(this._statesByAccount)
    .map((accountId) => this._statesByAccount[accountId].deltaStatus)
    .filter((deltaStatus) => deltaStatus != null)

    if (statuses.length === 0) {
      return true
    }

    return statuses.some((status) => {
      const connections = Object.keys(status)
      return connections.some((conn) => status[conn] !== 'closed')
    })
  }
}

export default new NylasSyncStatusStore()
