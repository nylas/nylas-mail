import _ from 'underscore'
import Rx from 'rx-lite'
import NylasStore from 'nylas-store'
import AccountStore from './account-store'
import DatabaseStore from './database-store'
import DeltaStreamingConnection from '../../services/delta-streaming-connection'


/**
 * DeltaConnectionStore manages delta connections and
 * keeps track of the status of delta connections
 * per account. It will  trigger whenever delta conenction
 * status changes.
 *
 * The connection status for any given account has the following shape:
 *
 * {
 *   cursor: 0,
 *   status: 'connected',
 * }
 *
 */
class DeltaConnectionStore extends NylasStore {

  constructor() {
    super()
    this._unsubscribers = []
    this._connectionStatesByAccountId = {}
    this._connectionsByAccountId = new Map()
    this._connectionStatusSubscriptionsByAccountId = new Map()

    this._isBuildingDeltaConnections = false

    this._triggerDebounced = _.debounce(this.trigger, 100)
  }

  async activate() {
    if (!NylasEnv.isWorkWindow()) { return }
    this._unsubsribers = [
      this.listenTo(AccountStore, () => this._onAccountsChanged()),
    ]
    const accountIds = AccountStore.accountIds()
    this._setupConnectionStatusSubscriptions({newAccountIds: accountIds})
    await this._setupDeltaStreamingConnections({newAccountIds: accountIds})
  }

  deactivate() {
    if (!NylasEnv.isWorkWindow()) { return }
    this._unsubsribers.forEach(usub => usub())
    for (const subscription of this._connectionStatusSubscriptionsByAccountId.values()) {
      subscription.dispose()
    }
    this._connectionStatusSubscriptionsByAccountId.clear()
  }

  getDeltaConnectionStates() {
    return this._connectionStatesByAccountId
  }

  _updateState(accountId, nextState) {
    const currentState = this._connectionStatesByAccountId[accountId] || {}
    if (_.isEqual(currentState, nextState)) { return }
    this._connectionStatesByAccountId[accountId] = nextState
    this._triggerDebounced()
  }

  async _onAccountsChanged() {
    const currentIds = Array.from(this._connectionStatusSubscriptionsByAccountId.keys())
    const nextIds = AccountStore.accountIds()
    const newAccountIds = _.difference(nextIds, currentIds)
    const removedAccountIds = _.difference(currentIds, nextIds)

    this._setupConnectionStatusSubscriptions({newAccountIds, removedAccountIds})
    await this._setupDeltaStreamingConnections({newAccountIds, removedAccountIds})
  }

  _setupConnectionStatusSubscriptions({newAccountIds = [], removedAccountIds = []} = {}) {
    removedAccountIds.forEach((accountId) => {
      if (this._connectionStatusSubscriptionsByAccountId.has(accountId)) {
        this._connectionStatusSubscriptionsByAccountId.get(accountId).dispose()
      }

      if (this._connectionStatesByAccountId[accountId]) {
        delete this._connectionStatesByAccountId[accountId]
        this._triggerDebounced()
      }
    })

    newAccountIds.forEach((accountId) => {
      if (this._connectionStatusSubscriptionsByAccountId.has(accountId)) { return; }
      const query = DatabaseStore.findJSONBlob(`DeltaStreamingConnectionStatus:${accountId}`)
      const subscription = Rx.Observable.fromQuery(query)
      .subscribe((json) => {
        // We need to copy `json` otherwise the query observable will mutate
        // the reference to that object
        this._updateState(accountId, {...json})
      })
      this._connectionStatusSubscriptionsByAccountId.set(accountId, subscription)
    })
  }

  async _setupDeltaStreamingConnections({newAccountIds = [], removedAccountIds = []} = {}) {
    if (NylasEnv.inSpecMode()) { return; }

    // We need a function lock on this because on bootup, many legitimate
    // events coming in may result in this function being called multiple times
    // in quick succession, which can cause us to start multiple syncs for the
    // same account
    if (this._isBuildingDeltaConnections) { return }
    this._isBuildingDeltaConnections = true;

    try {
      for (const accountId of newAccountIds) {
        const account = AccountStore.accountForId(accountId)
        const newDeltaConnection = new DeltaStreamingConnection(account);
        await newDeltaConnection.start()
        this._connectionsByAccountId.set(accountId, newDeltaConnection)
      }
      for (const accountId of removedAccountIds) {
        if (this._connectionsByAccountId.has(accountId)) {
          const connection = this._connectionsByAccountId.get(accountId)
          connection.end()
          this._connectionsByAccountId.delete(accountId)
        }
      }
    } finally {
      this._isBuildingDeltaConnections = false;
    }
  }
}

export default new DeltaConnectionStore()
