const TransactionConnector = require('../shared/transaction-connector')
const {DeltaStreamBuilder} = require('isomorphic-core')

export default class LocalSyncDeltaEmitter {
  constructor(db, accountId) {
    this._db = db;
    this._accountId = accountId;
    NylasEnv.localSyncEmitter.on("startDeltasFor", this._startDeltasFor)
    NylasEnv.localSyncEmitter.on("endDeltasFor", this._endDeltasFor)
    /**
     * The local-sync/sync-worker starts up asynchronously. We need to
     * notify N1 client that there are more deltas it should be looking
     * for.
     */
    NylasEnv.localSyncEmitter.emit("refreshLocalDeltas", accountId)
  }

  _startDeltasFor = ({accountId, cursor}) => {
    if (accountId !== this._accountId) return;
    if (this._disp && this._disp.dispose) this._disp.dispose()
    this._disp = DeltaStreamBuilder.buildDeltaObservable({
      db: this._db,
      cursor: cursor,
      accountId: accountId,
      deltasSource: TransactionConnector.getObservableForAccountId(accountId),
    }).subscribe((deltas) => {
      NylasEnv.localSyncEmitter.emit("localSyncDeltas", deltas)
    })
  }

  _endDeltasFor = ({accountId}) => {
    if (accountId !== this._accountId) return;
    if (this._disp && this._disp.dispose) this._disp.dispose()
  }
}
