import _ from 'underscore'
import {NylasLongConnection, DatabaseStore} from 'nylas-exports'

class DeltaStreamingConnection extends NylasLongConnection {
  constructor(api, accountId, opts = {}) {
    // TODO FYI this whole class is changing in an upcoming diff
    opts.api = api
    opts.accountId = accountId
    opts.throttleResultsInterval = 1000
    opts.closeIfDataStopsInterval = 15 * 1000

    // Update cursor when deltas received
    opts.onResuls = (deltas = []) => {
      if (opts.onDeltas) opts.onDeltas(deltas, {source: "n1Cloud"});
      const last = _.last(deltas);
      if (last && last.cursor) {
        this._setCursor(last.cursor)
      }
    }
    super(opts)

    this._onError = opts.onError || (() => {})

    const {getCursor, setCursor} = opts
    this._getCursor = getCursor
    this._setCursor = setCursor
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
