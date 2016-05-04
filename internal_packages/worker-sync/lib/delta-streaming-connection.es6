import {DatabaseStore} from 'nylas-exports'


class DeltaStreamingConnection {

  constructor(api, accountId, {ready, getCursor, setCursor, setStatus}) {
    this.api = api
    this.conn = null
    this.pingTimeout = null
    this.accountId = accountId
    this.ready = ready
    this.getCursor = getCursor
    this.setCursor = setCursor
    this.setStatus = setStatus
    this.deltaCallbacks = []
  }

  deltaStreamingPath(cursor) {
    return `/delta/streaming?cursor=${cursor}&exclude_folders=false&exclude_metadata=false&exclude_account=false`
  }

  hasCursor() {
    return !!this.getCursor()
  }

  withCursor(callback) {
    const cursor = this.getCursor()
    if (cursor) {
      return callback(cursor)
    }
    this.api.makeRequest({
      path: "/delta/latest_cursor",
      accountId: this.accountId,
      method: 'POST',
      success: (result) => {
        console.log(`Obtained stream cursor ${result.cursor}.`)
        this.setCursor(result.cursor)
        callback(result.cursor)
      },
    })
  }

  onDeltas(callback) {
    if (this.conn) {
      this.conn.onResults(callback)
    } else {
      this.deltaCallbacks.push(callback)
    }
  }

  start() {
    if (!this.ready()) {
      return
    }
    this.withCursor((cursor) => {
      if (!this.conn) {
        this.conn = this.api.longConnection({
          path: this.deltaStreamingPath(cursor),
          accountId: this.accountId,
          debounceInterval: 1000,
          onStatusChanged: (conn, status) => this.setStatus(status),
          onResults: (deltas) => {
            this.closeIfDataStops()
            this.deltaCallbacks.forEach(cb => cb(deltas))
          },
          onError: (err) => {
            if (err.message.indexOf('Invalid cursor') > 0) {
              const error = new Error('Delta Connection: Cursor is invalid. Need to blow away local cache.')
              NylasEnv.config.removeAtKeyPath("nylas.#{@_account.id}.cursor")
              DatabaseStore._handleSetupError(error)
            }
          },
        })
      }
      if (this.conn.hasEnded()) {
        return
      }
      this.conn.start()
    })
  }

  closeIfDataStops() {
    clearTimeout(this.pingTimeout)
    this.pingTimeout = setTimeout(() => {
      this.pingTimeout = null
      this.conn.close()
    }, 15 * 1000)
  }

  end() {
    clearTimeout(this.pingTimeout)
    this.pingTimeout = null
    if (this.conn) {
      this.conn.end()
    }
  }
}

export default DeltaStreamingConnection
