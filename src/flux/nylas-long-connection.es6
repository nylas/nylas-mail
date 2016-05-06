/* eslint global-require:0 */
import _ from 'underscore'
import url from 'url'
import {Emitter} from 'event-kit'

const CONNECTION_TIMEOUT = 60 * 60 * 1000
const RESULTS_THROTTLE = 400

export default class NylasLongConnection {
  static Statuses = {
    None: 'none',
    Idle: 'idle',
    Connecting: 'connecting',
    Connected: 'connected',
    Closed: 'closed', // Socket has been closed for any reason
    Ended: 'ended', // We have received 'end()' and will never open again.
  }

  constructor(api, accountId, {path, timeout, debounceInterval, throttleInterval, onStatusChanged, onError} = {}) {
    this._api = api
    this._accountId = accountId
    this._status = NylasLongConnection.Statuses.None
    this._req = null
    this._emitter = new Emitter()
    this._buffer = ''
    this._results = []

    // Options
    this._path = path
    this._timeout = timeout || CONNECTION_TIMEOUT
    this._debounceInterval = debounceInterval
    this._throttleInterval = throttleInterval || RESULTS_THROTTLE
    this._onStatusChanged = onStatusChanged || (() => {})
    this._onError = onError || (() => {})

    this._resultsReceived = () => {
      if (this._results.length === 0) {
        return
      }
      this._emitter.emit('results-stopped-arriving', this._results);
      this._results = []
    }
    if (this._debounceInterval != null) {
      this._resultsReceived = _.debounce(this._resultsReceived, this._debounceInterval)
    }
    return this
  }

  get accountId() {
    return this._accountId;
  }

  get status() {
    return this._status;
  }

  setStatus(status) {
    if (this._status === status) {
      return
    }
    this._status = status
    this._onStatusChanged(this, status)
  }

  onResults(callback) {
    this._emitter.on('results-stopped-arriving', callback)
  }

  processBuffer = () => {
    const bufferJSONs = this._buffer.split('\n')

    // We can't parse the last block - we don't know whether we've
    // received the entire result or only part of it. Wait
    // until we have more.
    this._buffer = bufferJSONs.pop()

    bufferJSONs.forEach((resultJSON) => {
      if (resultJSON.length === 0) {
        return
      }
      let result = null
      try {
        result = JSON.parse(resultJSON)
        if (result) {
          this._results.push(result)
        }
      } catch (e) {
        console.error(`${resultJSON} could not be parsed as JSON.`, e)
      }
    })
    this._resultsReceived()
  }

  start() {
    const canStart = (
      [NylasLongConnection.Statuses.None, NylasLongConnection.Statuses.Closed].includes(this._status)
    )
    if (!canStart) {
      return this;
    }

    const token = this._api.accessTokenForAccountId(this._accountId)
    if (!token || this._req) {
      return this;
    }

    const options = url.parse(`${this._api.APIRoot}${this._path}`)
    options.auth = `${token}:`

    let lib;
    if (this._api.APIRoot.indexOf('https') === -1) {
      lib = require('http')
    } else {
      options.port = 443
      lib = require('https')
    }

    const processBufferThrottled = _.throttle(this.processBuffer, this._throttleInterval, {leading: false})
    this._req = lib.request(options, (responseStream) => {
      if (responseStream.statusCode !== 200) {
        responseStream.on('data', (chunk) => {
          const message = chunk.toString('utf8')
          console.error(message)
          this._onError({message})
          this.close()
        })
        return;
      }

      responseStream.setEncoding('utf8')
      responseStream.on('close', () => {
        this.close()
      })
      responseStream.on('data', (chunk) => {
        if (this.isClosed()) {
          return;
        }

        // Ignore redundant newlines sent as pings. Want to avoid
        // calls to this.onProcessBuffer that contain no actual updates
        if (chunk === '\n' && (this._buffer.length === 0 || this._buffer[-1] === '\n')) {
          return
        }
        this._buffer += chunk
        processBufferThrottled()
      })
    })
    this._req.setTimeout(this._timeout)
    this._req.setSocketKeepAlive(true)
    this._req.on('error', (err) => {
      this._onError(err)
      this.close()
    })
    this._req.on('socket', (socket) => {
      this.setStatus(NylasLongConnection.Statuses.Connecting)
      socket.on('connect', () => {
        this.setStatus(NylasLongConnection.Statuses.Connected)
      })
    })
    this._req.end()
    return this
  }

  hasEnded() {
    return this._status === NylasLongConnection.Statuses.Ended
  }

  isClosed() {
    return [
      NylasLongConnection.Statuses.None,
      NylasLongConnection.Statuses.Closed,
      NylasLongConnection.Statuses.Ended,
    ].includes(this._status)
  }

  close() {
    return this.dispose(NylasLongConnection.Statuses.Closed)
  }

  end() {
    return this.dispose(NylasLongConnection.Statuses.Ended)
  }

  dispose(status) {
    this._emitter.dispose()
    this._buffer = ''
    if (this._req) {
      this._req.end()
      this._req.abort()
      this._req = null
    }
    if (this._status !== status) {
      this.setStatus(status)
    }
    return this
  }
}
