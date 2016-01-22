{Emitter} = require 'event-kit'
url = require 'url'
_ = require 'underscore'

class NylasLongConnection

  @State =
    Idle: 'idle'
    Ended: 'ended'
    Connecting: 'connecting'
    Connected: 'connected'
    Retrying: 'retrying'

  constructor: (api, accountId) ->
    @_api = api
    @_accountId = accountId
    @_cursorKey = "nylas.#{@_accountId}.cursor"
    @_emitter = new Emitter
    @_state = 'idle'
    @_req = null
    @_reqForceReconnectInterval = null
    @_buffer = null

    @_deltas = []
    @_flushDeltasDebounced = _.debounce =>

      return if @_deltas.length is 0
      last = @_deltas[@_deltas.length - 1]

      @_emitter.emit('deltas-stopped-arriving', @_deltas)
      @_deltas = []

      # Note: setCursor is slow and saves to disk, so we do it once at the end
      @setCursor(last.cursor)
    , 1000

    @

  accountId: ->
    @_accountId

  hasCursor: ->
    !!NylasEnv.config.get(@_cursorKey)

  withCursor: (callback) ->
    cursor = NylasEnv.config.get(@_cursorKey)
    return callback(cursor) if cursor

    @_api.makeRequest
      path: "/delta/latest_cursor"
      accountId: @_accountId
      method: 'POST'
      success: ({cursor}) =>
        console.log("Obtained stream cursor #{cursor}.")
        @setCursor(cursor)
        callback(cursor)

  setCursor: (cursor) ->
    NylasEnv.config.set(@_cursorKey, cursor)

  state: ->
    @state

  setState: (state) ->
    @_state = state
    @_emitter.emit('state-change', state)

  onStateChange: (callback) ->
    @_emitter.on('state-change', callback)

  onDeltas: (callback) ->
    @_emitter.on('deltas-stopped-arriving', callback)

  onProcessBuffer: =>
    bufferJSONs = @_buffer.split('\n')

    # We can't parse the last block - we don't know whether we've
    # received the entire delta or only part of it. Wait
    # until we have more.
    @_buffer = bufferJSONs.pop()

    for deltaJSON in bufferJSONs
      continue if deltaJSON.length is 0
      delta = null
      try
        delta = JSON.parse(deltaJSON)
      catch e
        console.log("#{deltaJSON} could not be parsed as JSON.", e)
      if delta
        throw (new Error 'Received delta with no cursor!') unless delta.cursor
        @_deltas.push(delta)
        @_flushDeltasDebounced()

  start: ->
    token = @_api.accessTokenForAccountId(@_accountId)
    return if not token?
    return if @_state is NylasLongConnection.State.Ended
    return if @_req

    @withCursor (cursor) =>
      return if @state is NylasLongConnection.State.Ended
      console.log("Long Polling Connection: Starting for account #{@_accountId}, token #{token}, with cursor #{cursor}")
      options = url.parse("#{@_api.APIRoot}/delta/streaming?cursor=#{cursor}&exclude_folders=false")
      options.auth = "#{token}:"

      if @_api.APIRoot.indexOf('https') is -1
        lib = require 'http'
      else
        options.port = 443
        lib = require 'https'

      req = lib.request options, (res) =>
        if res.statusCode isnt 200
          res.on 'data', (chunk) =>
            if chunk.toString().indexOf('Invalid cursor') > 0
              console.log('Long Polling Connection: Cursor is invalid. Need to blow away local cache.')
              # TODO THIS!
            else
              @retry()
          return

        @_buffer = ''
        processBufferThrottled = _.throttle(@onProcessBuffer, 400, {leading: false})
        res.setEncoding('utf8')
        res.on 'close', => @retry()
        res.on 'data', (chunk) =>
          # Ignore redundant newlines sent as pings. Want to avoid
          # calls to @onProcessBuffer that contain no actual updates
          return if chunk is '\n' and (@_buffer.length is 0 or @_buffer[-1] is '\n')
          @_buffer += chunk
          processBufferThrottled()

      req.setTimeout(60*60*1000)
      req.setSocketKeepAlive(true)
      req.on 'error', => @retry()
      req.on 'socket', (socket) =>
        @setState(NylasLongConnection.State.Connecting)
        socket.on 'connect', =>
          @setState(NylasLongConnection.State.Connected)
      req.write("1")

      @_req = req

      # Currently we have trouble identifying when the connection has closed.
      # Instead of trying to fix that, just reconnect every 120 seconds.
      @_reqForceReconnectInterval = setInterval =>
        @retry(true)
      ,30000

  retry: (immediate = false) ->
    return if @_state is NylasLongConnection.State.Ended
    @setState(NylasLongConnection.State.Retrying)
    @cleanup()

    startDelay = if immediate then 0 else 10000
    setTimeout =>
      @start()
    , startDelay

  end: ->
    console.log("Long Polling Connection: Closed.")
    @setState(NylasLongConnection.State.Ended)
    @cleanup()

  cleanup: ->
    clearInterval(@_reqForceReconnectInterval) if @_reqForceReconnectInterval
    @_reqForceReconnectInterval = null
    @_buffer = ''
    if @_req
      @_req.end()
      @_req.abort()
      @_req = null

module.exports = NylasLongConnection
