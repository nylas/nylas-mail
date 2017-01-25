import _ from 'underscore'
import {NylasLongConnection, DatabaseStore} from 'nylas-exports'

class DeltaStreamingConnection extends NylasLongConnection {
  constructor(api, accountId, opts = {}) {
    opts.throttleResultsInterval = 1000
    opts.closeIfDataStopsInterval = 15 * 1000
    super(api, accountId, opts)

    const {getCursor, setCursor} = opts
    this._getCursor = getCursor
    this._setCursor = setCursor

    // Update cursor when deltas received
    this.onDeltas((deltas) => {
      if (opts.onDeltas) opts.onDeltas(deltas);
      const last = _.last(deltas)
      this._setCursor(last.cursor)
    })
  }

  _deltaStreamingPath(cursor) {
    return `/delta/streaming?cursor=${cursor}`
  }

  onError(err) {
    if (err.message.indexOf('Invalid cursor') > 0) {
      const error = new Error('Delta Connection: Cursor is invalid. Need to blow away local cache.');
      this._setCursor(0)
      DatabaseStore._handleSetupError(error)
    }
  }

  onDeltas(callback) {
    return this.onResults(callback)
  }

  start() {
    this._path = this._deltaStreamingPath(this._getCursor() || 0)
    super.start()
  }
}

export default DeltaStreamingConnection
