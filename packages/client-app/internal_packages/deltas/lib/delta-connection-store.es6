import _ from 'underscore';
import {AccountStore} from 'nylas-exports'
import AccountDeltaConnection from './account-delta-connection';


class DeltaConnectionStore {
  constructor() {
    this._accountConnections = [];
    this._unsubscribe = () => {}
  }

  activate() {
    this._unsubscribe = AccountStore.listen(this._ensureConnections, this);
    this._ensureConnections();
  }

  deactivate() {
    this._unsubscribe()
  }

  _existingConnectionsForAccount(account) {
    return _.find(this._accountConnections, c => c.account().id === account.id);
  }

  async _ensureConnections() {
    if (NylasEnv.inSpecMode()) { return; }

    // we need a function lock on this because on bootup, many legitimate
    // events coming in may result in this function being called multiple times
    // in quick succession, which can cause us to start multiple syncs for the
    // same account
    if (this._isBuildingDeltaConnections) { return }
    this._isBuildingDeltaConnections = true;

    try {
      const originalConnections = this._accountConnections;
      const currentConnections = []
      for (const account of AccountStore.accounts()) {
        const existingDeltaConnection = this._existingConnectionsForAccount(account)
        if (existingDeltaConnection) {
          currentConnections.push(existingDeltaConnection);
          continue
        }

        const newDeltaConnection = new AccountDeltaConnection(account);
        await newDeltaConnection.loadStateFromDatabase()
        newDeltaConnection.start()
        currentConnections.push(newDeltaConnection);
      }
      const oldDeltaConnections = _.difference(originalConnections, currentConnections);
      for (const deltaConnection of oldDeltaConnections) {
        deltaConnection.end()
      }
      this._accountConnections = currentConnections;
    } finally {
      this._isBuildingDeltaConnections = false;
    }
  }
}

export default new DeltaConnectionStore()
