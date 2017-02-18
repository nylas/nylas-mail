/**
 * This implements the same interface as the DeltaStreamingConnection
 */
class DeltaStreamingInMemoryConnection {
  constructor(accountId, opts) {
    this._accountId = accountId
    this._getCursor = opts.getCursor
    this._setCursor = opts.setCursor
    this._onDeltas = opts.onDeltas
    this._onStatusChanged = opts.onStatusChanged
    this._status = "none"
  }

  onDeltas = (allDeltas = []) => {
    const deltas = allDeltas.filter((d) => d.accountId === this._accountId);
    this._onDeltas(deltas, {source: "localSync"});
    const last = deltas[deltas.length - 1]
    if (last) this._setCursor(last.cursor);
  }

  get accountId() {
    return this._accountId;
  }

  get status() {
    return this._status;
  }

  setStatus(status) {
    this._status = status
    this._onStatusChanged(status)
  }

  start() {
    this._disp = NylasEnv.localSyncEmitter.on("localSyncDeltas", this.onDeltas);
    NylasEnv.localSyncEmitter.emit("startDeltasFor", {
      cursor: this._getCursor() || 0,
      accountId: this._accountId,
    })
    this.setStatus("connected")
  }

  end() {
    if (this._disp && this._disp.dispose) this._disp.dispose()
    NylasEnv.localSyncEmitter.emit("endDeltasFor", {
      accountId: this._accountId,
    })
    this.setStatus("ended")
  }
}

export default DeltaStreamingInMemoryConnection
