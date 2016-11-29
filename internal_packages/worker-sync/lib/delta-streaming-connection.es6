import _ from 'underscore'
import {NylasAPIRequest, NylasLongConnection, DatabaseStore} from 'nylas-exports'

class DeltaStreamingConnection extends NylasLongConnection {

  constructor(api, accountId, opts = {}) {
    opts.throttleResultsInterval = 1000
    opts.closeIfDataStopsInterval = 15 * 1000
    super(api, accountId, opts)

    const {isReady, getCursor, setCursor} = opts
    this._isReady = isReady
    this._getCursor = getCursor
    this._setCursor = setCursor

    // Update cursor when deltas received
    this.onDeltas((deltas) => {
      const last = _.last(deltas)
      this._setCursor(last.cursor)
    })
  }

  deltaStreamingPath(cursor) {
    return `/delta/streaming?cursor=${cursor}&exclude_folders=false&exclude_metadata=false&exclude_account=false`
  }

  hasCursor() {
    return !!this._getCursor()
  }

  onError(err) {
    if (err.message.indexOf('Invalid cursor') > 0) {
      const error = new Error('Delta Connection: Cursor is invalid. Need to blow away local cache.')
      NylasEnv.config.unset(`nylas.${this._accountId}.cursor`)
      DatabaseStore._handleSetupError(error)
    }
  }

  latestCursor() {
    const cursor = this._getCursor()
    if (cursor) { return Promise.resolve(cursor) }
    const request = new NylasAPIRequest({
      api: this._api,
      options: {
        path: "/delta/latest_cursor",
        accountId: this._accountId,
        method: 'POST',
      },
    })
    return request.run().then((result) => {
      if (!result) throw new Error(`No cursor returned from ${this._api.APIRoot}/delta/latest_cursor`)
      this._setCursor(result.cursor)
      return Promise.resolve(result.cursor)
    })
  }

  onDeltas(callback) {
    return this.onResults(callback)
  }

  start() {
    if (!this._isReady()) { return }
    if (!this.canStart()) { return }
    if (this._req != null) { return }

    this.latestCursor().then((cursor) => {
      if (!cursor) { return }
      this._path = this.deltaStreamingPath(cursor)
      super.start()
    })
    .catch((error) => {
      console.error(`Can't establish DeltaStreamingConnection: Error fetching latest cursor`, error)
    })
  }
}

export default DeltaStreamingConnection
