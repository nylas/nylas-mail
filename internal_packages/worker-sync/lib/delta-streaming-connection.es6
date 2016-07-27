import {NylasLongConnection, DatabaseStore} from 'nylas-exports'

const {Status} = NylasLongConnection


class DeltaStreamingConnection extends NylasLongConnection {

  constructor(api, accountId, opts = {}) {
    opts.debounceInterval = 1000
    opts.closeIfDataStopsInterval = 15 * 1000
    super(api, accountId, opts)

    const {ready, getCursor, setCursor, setStatus} = opts
    this._ready = ready
    this._getCursor = getCursor
    this._setCursor = setCursor

    // Override super class instance vars
    this._onStatusChanged = setStatus
    this._onError = (err) => {
      if (err.message.indexOf('Invalid cursor') > 0) {
        const error = new Error('Delta Connection: Cursor is invalid. Need to blow away local cache.')
        NylasEnv.config.unset(`nylas.${this._accountId}.cursor`)
        DatabaseStore._handleSetupError(error)
      }
    }
  }

  deltaStreamingPath(cursor) {
    return `/delta/streaming?cursor=${cursor}&exclude_folders=false&exclude_metadata=false&exclude_account=false`
  }

  hasCursor() {
    return !!this._getCursor()
  }

  latestCursor() {
    const cursor = this._getCursor()
    if (cursor) { return Promise.resolve(cursor) }
    return this._api.makeRequest({
      path: "/delta/latest_cursor",
      accountId: this._accountId,
      method: 'POST',
    })
    .then((result) => {
      console.log(`Obtained stream cursor ${result.cursor}.`)
      this._setCursor(result.cursor)
      return Promise.resolve(result.cursor)
    })
  }

  onDeltas(callback) {
    return this.onResults(callback)
  }

  start() {
    if (!this._ready()) { return }
    if (!this.canStart()) { return }
    if (this._req != null) { return }

    this.latestCursor().then((cursor) => {
      if (this._status === Status.Ended) { return }
      this._path = this.deltaStreamingPath(cursor)
      super.start()
    })
    .catch((error) => {
      console.error(`Can't establish DeltaStreamingConnection: Error fetching latest cursor`, error)
    })
  }
}

export default DeltaStreamingConnection
