import _ from 'underscore';
import {AccountStore} from 'nylas-exports'
import AccountDeltaConnection from './account-delta-connection';

export default class AccountDeltaConnectionPool {
  constructor() {
    this._accountConnections = [];
    AccountStore.listen(this._determineDeltaConnectionPool, this);
    this._determineDeltaConnectionPool();
  }

  _existingConnectionsForAccount(account) {
    return _.find(this._accountConnections, c => c.account().id === account.id);
  }

  _determineDeltaConnectionPool() {
    // we need a function lock on this because on bootup, many legitimate
    // events coming in may result in this function being called multiple times
    // in quick succession, which can cause us to start multiple syncs for the
    // same account
    if (this._isBuildingDeltaConnections) return;
    this._isBuildingDeltaConnections = true;
    if (NylasEnv.inSpecMode()) { return; }
    const origDeltaConnections = this._accountConnections;
    const currentDeltaConnections = []
    Promise.each(AccountStore.accounts(), (account) => {
      const existingDeltaConnection = this._existingConnectionsForAccount(account)
      if (existingDeltaConnection) {
        currentDeltaConnections.push(existingDeltaConnection);
        return Promise.resolve()
      }

      const newDeltaConnection = new AccountDeltaConnection(account);
      return newDeltaConnection.loadStateFromDatabase().then(() => {
        newDeltaConnection.start()
        currentDeltaConnections.push(newDeltaConnection);
      })
    }).then(() => {
      const oldDeltaConnections = _.difference(origDeltaConnections, currentDeltaConnections);
      for (const deltaConnection of oldDeltaConnections) { deltaConnection.cleanup() }
      this._accountConnections = currentDeltaConnections;
    }).finally(() => {
      this._isBuildingDeltaConnections = false;
    })
  }
}
