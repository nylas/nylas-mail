import _ from 'underscore'
import Rx from 'rx-lite'
import NylasStore from 'nylas-store'
import AccountStore from './account-store'
import DatabaseStore from './database-store'


/**
 * DeltaConnectionStatusStore keeps track of the state of delta connections
 * per account, and will  trigger whenever it changes.
 *
 * The sync state for any given account has the following shape:
 *
 * {
 *   cursor: 0,
 *   status: 'connected',
 * }
 *
 */
class DeltaConnectionStatusStore extends NylasStore {

  constructor() {
    super()
    this._statesByAccount = {}
    this._accountSubscriptions = new Map()
    this._triggerDebounced = _.debounce(this.trigger, 100)
  }

  activate() {
    this.listenTo(AccountStore, () => this._onAccountsChanged())
    this._setupAccountSubscriptions(AccountStore.accountIds())
  }

  getDeltaConnectionStates() {
    return this._statesByAccount
  }

  _setupAccountSubscriptions(accountIds) {
    accountIds.forEach((accountId) => {
      if (this._accountSubscriptions.has(accountId)) { return; }
      const query = DatabaseStore.findJSONBlob(`DeltaStreamingConnectionStatus:${accountId}`)
      const sub = Rx.Observable.fromQuery(query)
      .subscribe((json) => {
        // We need to copy `json` otherwise the query observable will mutate
        // the reference to that object
        this._updateState(accountId, {...json})
      })
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

  _updateState(accountId, nextState) {
    const currentState = this._statesByAccount[accountId] || {}
    if (_.isEqual(currentState, nextState)) { return }
    this._statesByAccount[accountId] = nextState
    this._triggerDebounced()
  }
}

export default new DeltaConnectionStatusStore()
