import _ from 'underscore'
import {DeltaStreamBuilder} from 'isomorphic-core'
import {DatabaseStore, DeltaProcessor} from 'nylas-exports'
import TransactionConnector from '../shared/transaction-connector'


export default class LocalSyncDeltaEmitter {
  constructor(account, db) {
    this._db = db;
    this._state = null
    this._account = account;
    this._disposable = {dispose: () => {}}
    this._writeStateDebounced = _.debounce(this._writeState, 100)
  }

  async activate() {
    if (this._disposable && this._disposable.dispose) {
      this._disposable.dispose()
    }
    if (!this._state) {
      this._state = await this._loadState()
    }
    const {cursor = 0} = this._state
    this._disposable = DeltaStreamBuilder.buildDeltaObservable({
      cursor,
      db: this._db,
      accountId: this._account.id,
      deltasSource: TransactionConnector.getObservableForAccountId(this._account.id),
    })
    .subscribe((deltas) => {
      this._onDeltasReceived(deltas)
    })
  }

  deactivate() {
    this._state = null
    if (this._disposable && this._disposable.dispose) {
      this._disposable.dispose()
    }
  }

  _onDeltasReceived(deltas = []) {
    const last = deltas[deltas.length - 1]
    if (last) {
      this._state.cursor = last.cursor;
      this._writeStateDebounced();
    }
    DeltaProcessor.process(deltas, {source: "localSync"})
  }

  async _loadState() {
    const json = await DatabaseStore.findJSONBlob(`LocalSyncStatus:${this._account.id}`)
    if (json) {
      return json
    }

    // Migrate from old storage key
    const oldState = await DatabaseStore.findJSONBlob(`NylasSyncWorker:${this._account.id}`)
    if (!oldState) {
      return {}
    }

    const {deltaCursors = {}} = oldState
    return {cursor: deltaCursors.localSync}
  }

  async _writeState() {
    if (!this._state) { return }
    await DatabaseStore.inTransaction(t =>
      t.persistJSONBlob(`LocalSyncStatus:${this._account.id}`, this._state)
    );
  }
}
