/* eslint global-require: 0 */
import _ from 'underscore'
import url from 'url'
import {Emitter} from 'event-kit'
import {IdentityStore} from 'nylas-exports'


const CONNECTION_TIMEOUT = 60 * 60 * 1000
const PROCESS_RESULTS_THROTTLE = 400
const Status = {
  None: 'none',
  Connecting: 'connecting',
  Connected: 'connected',
  Closed: 'closed', // Socket has been closed for any reason
  Ended: 'ended', // We have received 'end()' and will never open again.
}

class NylasLongConnection {
  static Status = Status

  constructor(api, accountId, opts = {}) {
    const {
      path,
      timeout,
      onError,
      onStatusChanged,
      debounceInterval,
      closeIfDataStopsInterval,
    } = opts

    this._api = api
    this._accountId = accountId
    this._status = Status.None
    this._emitter = new Emitter()
    this._req = null
    this._buffer = ''
    this._results = []
    this._pingTimeout = null
    this._statusCode = null

    // Options
    this._path = path
    this._timeout = timeout || CONNECTION_TIMEOUT
    this._onError = onError || (() => {})
    this._onStatusChanged = onStatusChanged || (() => {})
    this._debounceInterval = debounceInterval
    this._closeIfDataStopsInterval = closeIfDataStopsInterval

    this._flushResults = () => {
      if (this._results.length === 0) { return }
      this._emitter.emit('results-stopped-arriving', this._results);
      this._results = []
    }
    if (this._debounceInterval != null) {
      this._flushResults = _.debounce(this._flushResults, this._debounceInterval)
    }
  }

  _processBufffer = _.throttle(() => {
    const bufferJSONs = this._buffer.split('\n')

    // We can't parse the last block - we don't know whether we've
    // received the entire result or only part of it. Wait
    // until we have more.
    this._buffer = bufferJSONs.pop()

    bufferJSONs.forEach((resultJSON) => {
      if (resultJSON.length === 0) { return }
      let result = null
      try {
        result = JSON.parse(resultJSON)
      } catch (e) {
        console.error(`${resultJSON} could not be parsed as JSON.`, e)
      }
      if (result) {
        this._results.push(result)
      }
    })
    this._flushResults()
  }, PROCESS_RESULTS_THROTTLE, {leading: false})

  get accountId() {
    return this._accountId;
  }

  get status() {
    return this._status;
  }

  setStatus(status) {
    if (this._status === status) { return }
    this._status = status
    this._onStatusChanged(status, this._statusCode)
  }

  onResults(callback) {
    this._emitter.on('results-stopped-arriving', callback)
  }

  canStart() {
    return [Status.None, Status.Closed].includes(this._status)
  }

  start() {
    if (!this.canStart()) { return this }
    if (this._req != null) { return this }

    const accountToken = this._api.accessTokenForAccountId(this._accountId)
    const identityToken = (IdentityStore.identity() || {}).token || ''
    if (!accountToken) {
      console.error(`Can't establish NylasLongConnection: No account token available for account ${this._accountId}`)
      return this;
    }

    const options = url.parse(`${this._api.APIRoot}${this._path}`)
    options.auth = `${accountToken}:${identityToken}`

    let lib;
    if (this._api.APIRoot.indexOf('https') === -1) {
      lib = require('http')
    } else {
      lib = require('https')
    }

    this._req = lib.request(options, (responseStream) => {
      this._statusCode = responseStream.statusCode
      if (responseStream.statusCode !== 200) {
        responseStream.on('data', (chunk) => {
          const error = new Error(chunk.toString('utf8'))
          console.error(error)
          this._onError(error)
          this.close()
        })
        return
      }

      responseStream.setEncoding('utf8')
      responseStream.on('close', () => this.close())
      responseStream.on('end', () => this.close())
      responseStream.on('data', (chunk) => {
        this.closeIfDataStops()
        // Ignore redundant newlines sent as pings. Want to avoid
        // calls to this.onProcessBuffer that contain no actual updates
        if (chunk === '\n' && (this._buffer.length === 0 || _.last(this._buffer) === '\n')) {
          return
        }
        this._buffer += chunk
        this._processBufffer()
      })
    })
    this._req.setTimeout(60 * 60 * 1000)
    this._req.setSocketKeepAlive(true)
    this._req.on('error', (err) => {
      console.error(err)
      this._onError(err)
      this.close()
    })
    this._req.on('socket', (socket) => {
      this.setStatus(Status.Connecting)
      socket.on('connect', () => {
        this.setStatus(Status.Connected)
        this.closeIfDataStops()
      })
    })
    this._req.end()
    return this
  }

  closeIfDataStops() {
    if (this._closeIfDataStopsInterval != null) {
      clearTimeout(this._pingTimeout)
      this._pingTimeout = setTimeout(() => {
        this._pingTimeout = null
        this.close()
      }, this._closeIfDataStopsInterval)
    }
  }

  dispose(status) {
    if (this._status !== status) {
      this.setStatus(status)
    }
    clearTimeout(this._pingTimeout)
    this._pingTimeout = null
    this._statusCode = null
    this._buffer = ''
    if (this._req) {
      this._req.end()
      this._req.abort()
      this._req = null
    }
    return this
  }

  close() {
    return this.dispose(Status.Closed)
  }

  end() {
    return this.dispose(Status.Ended)
  }
}

export default NylasLongConnection
