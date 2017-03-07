import _ from 'underscore';
import {AccountStore} from 'nylas-exports'
import DeltaStreamingConnection from './delta-streaming-connection';


class DeltaConnectionStore {
  constructor() {
    this._connections = [];
    this._unsubscribe = () => {}
  }

  activate() {
    this._unsubscribe = AccountStore.listen(this._ensureConnections, this);
    this._ensureConnections();
  }

  deactivate() {
    this._unsubscribe()
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
      const currentConnections = this._connections;
      const nextConnections = []
      for (const account of AccountStore.accounts()) {
        const existingConnection = (
          currentConnections
          .find(conn => conn.account().id === account.id)
        )
        if (existingConnection) {
          nextConnections.push(existingConnection);
          continue
        }

        const newDeltaConnection = new DeltaStreamingConnection(account);
        await newDeltaConnection.start()
        nextConnections.push(newDeltaConnection);
      }
      const oldDeltaConnections = _.difference(currentConnections, nextConnections);
      for (const deltaConnection of oldDeltaConnections) {
        deltaConnection.end()
      }
      this._connections = nextConnections;
    } finally {
      this._isBuildingDeltaConnections = false;
    }
  }
}

export default new DeltaConnectionStore()
