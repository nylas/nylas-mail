import _ from 'underscore'
import url from 'url'
import {Emitter} from 'event-kit'


class NylasLongConnection {

  static Status = {
    None: 'none',
    Connecting: 'connecting',
    Connected: 'connected',
    Closed: 'closed', // Socket has been closed for any reason
    Ended: 'ended', // We have received 'end()' and will never open again.
  }

  constructor(api, accountId, {path, debounceInterval, throttleInterval, closeIfDataStopsTimeout, onStatusChanged} = {}) {
    this._api = api
    this._accountId = accountId
    this._status = NylasLongConnection.Status.None
    this._req = null
    this._pingTimeout = null
    this._emitter = new Emitter()
    this._buffer = ''
    this._results = []

    // Options
    this._path = path
    this._debounceInterval = debounceInterval
    this._throttleInterval = throttleInterval || 400
    this._closeIfDataStopsTimeout = closeIfDataStopsTimeout || (15 * 1000)
    this._onStatusChanged = onStatusChanged || () => {}


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
    const isValidStatus = (
      [NylasLongConnection.Status.None, NylasLongConnection.Status.Closed].includes(this._status)
    )
    if (!isValidStatus) {
      return this;
    }

    const token = this._api.accessTokenForAccountId(this._accountId)
    if (!token || this._req) {
      return null;
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
        responseStream.on('data', () => {
          this.close()
        })
        return;
      }

      responseStream.setEncoding('utf8')
      responseStream.on('close', () => {
        this.close()
      })
      responseStream.on('data', (chunk) => {
        this.closeIfDataStops()

        // Ignore redundant newlines sent as pings. Want to avoid
        // calls to @onProcessBuffer that contain no actual updates
        if (chunk === '\n' && (this._buffer.length === 0 || this._buffer[-1] === '\n')) {
          return
        }
        this._buffer += chunk
        processBufferThrottled()
      })
    })
    this._req.setTimeout(60 * 60 * 1000)
    this._req.setSocketKeepAlive(true)
    this._req.on('error', () => this.close())
    this._req.on('socket', (socket) => {
      this.setStatus(NylasLongConnection.Status.Connecting)
      socket.on('connect', () => {
        this.setStatus(NylasLongConnection.Status.Connected)
        this.closeIfDataStops()
      })
    })
    this._req.write("1")
    return this
  }

  cleanup() {
    if (this._pingTimeout) {
      clearTimeout(this._pingTimeout)
    }
    this._pingTimeout = null
    this._buffer = ''
    if (this._req) {
      this._req.end()
      this._req.abort()
      this._req = null
    }
    return this
  }

  isClosed() {
    return [
      NylasLongConnection.Status.None,
      NylasLongConnection.Status.Closed,
      NylasLongConnection.Status.Ended,
    ].includes(this._status)
  }

  close() {
    if (this._status === NylasLongConnection.Status.Closed) {
      return
    }
    this.setStatus(NylasLongConnection.Status.Closed)
    this.cleanup()
  }

  closeIfDataStops() {
    if (this._pingTimeout) {
      clearTimeout(this._pingTimeout)
    }
    this._pingTimeout = setTimeout(() => {
      this._pingTimeout = null
      this.close()
    }, this._closeIfDataStopsTimeout)
  }

  end() {
    this.setStatus(NylasLongConnection.Status.Ended)
    this.cleanup()
  }
}

export default NylasLongConnection
