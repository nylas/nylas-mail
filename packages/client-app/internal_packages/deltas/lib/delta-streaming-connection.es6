import _ from 'underscore'
import {NylasLongConnection, DatabaseStore} from 'nylas-exports'

class DeltaStreamingConnection extends NylasLongConnection {
  constructor(api, accountId, opts = {}) {
    opts.throttleResultsInterval = 1000
    opts.closeIfDataStopsInterval = 15 * 1000
    super(api, accountId, opts)

    this._onError = opts.onError || (() => {})

    const {getCursor, setCursor} = opts
    this._getCursor = getCursor
    this._setCursor = setCursor

    // Update cursor when deltas received
    this.onResults((deltas = []) => {
      if (opts.onDeltas) opts.onDeltas(deltas, {source: "n1Cloud"});
      const last = _.last(deltas);
      if (last && last.cursor) {
        this._setCursor(last.cursor)
      }
    })
  }

  _deltaStreamingPath(cursor) {
    return `/delta/streaming?cursor=${cursor}`
  }

  onError(err = {}) {
    if (err.message && err.message.includes('Invalid cursor')) {
      const error = new Error('Delta Connection: Cursor is invalid. Need to blow away local cache.');
      NylasEnv.reportError(error)
      this._setCursor(0)
      DatabaseStore._handleSetupError(error)
    }
    this._onError(err)
  }

  start() {
    this._path = this._deltaStreamingPath(this._getCursor() || 0)
    super.start()
  }
}

export default DeltaStreamingConnection
