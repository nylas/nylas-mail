{Emitter} = require 'event-kit'
url = require 'url'
_ = require 'underscore'

class NylasLongConnection

  @Status =
    None: 'none'
    Connecting: 'connecting'
    Connected: 'connected'
    Closed: 'closed' # Socket has been closed for any reason
    Ended: 'ended' # We have received 'end()' and will never open again.

  constructor: (api, accountId, config) ->
    @_api = api
    @_accountId = accountId
    @_config = config
    @_emitter = new Emitter
    @_status = NylasLongConnection.Status.None
    @_req = null
    @_pingTimeout = null
    @_buffer = null

    @_deltas = []
    @_flushDeltasDebounced = _.debounce =>

      return if @_deltas.length is 0
      last = @_deltas[@_deltas.length - 1]

      @_emitter.emit('deltas-stopped-arriving', @_deltas)
      @_config.setCursor(last.cursor)
      @_deltas = []

    , 1000

    @

  accountId: ->
    @_accountId

  hasCursor: ->
    !!@_config.getCursor()

  withCursor: (callback) ->
    cursor = @_config.getCursor()
    return callback(cursor) if cursor

    @_api.makeRequest
      path: "/delta/latest_cursor"
      accountId: @_accountId
      method: 'POST'
      success: ({cursor}) =>
        console.log("Obtained stream cursor #{cursor}.")
        @_config.setCursor(cursor)
        callback(cursor)

  status: ->
    @status

  setStatus: (status) ->
    return if @_status is status
    @_status = status
    @_config.setStatus(status)

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
    return unless @_config.ready()
    return unless @_status in [NylasLongConnection.Status.None, NylasLongConnection.Status.Closed]

    token = @_api.accessTokenForAccountId(@_accountId)
    return if not token?
    return if @_req

    @withCursor (cursor) =>
      return if @status is NylasLongConnection.Status.Ended

      options = url.parse("#{@_api.APIRoot}/delta/streaming?cursor=#{cursor}&exclude_folders=false&exclude_metadata=false&exclude_account=false")
      options.auth = "#{token}:"

      if @_api.APIRoot.indexOf('https') is -1
        lib = require 'http'
      else
        options.port = 443
        lib = require 'https'

      @_req = lib.request options, (res) =>
        if res.statusCode isnt 200
          res.on 'data', (chunk) =>
            if chunk.toString().indexOf('Invalid cursor') > 0
              console.log('Delta Connection: Cursor is invalid. Need to blow away local cache.')
              # TODO THIS!
            else
              @close()
          return

        @_buffer = ''
        processBufferThrottled = _.throttle(@onProcessBuffer, 400, {leading: false})
        res.setEncoding('utf8')
        res.on 'close', => @close()
        res.on 'data', (chunk) =>
          @closeIfDataStops()
          # Ignore redundant newlines sent as pings. Want to avoid
          # calls to @onProcessBuffer that contain no actual updates
          return if chunk is '\n' and (@_buffer.length is 0 or @_buffer[-1] is '\n')
          @_buffer += chunk
          processBufferThrottled()

      @_req.setTimeout(60*60*1000)
      @_req.setSocketKeepAlive(true)
      @_req.on 'error', => @close()
      @_req.on 'socket', (socket) =>
        @setStatus(NylasLongConnection.Status.Connecting)
        socket.on 'connect', =>
          @setStatus(NylasLongConnection.Status.Connected)
          @closeIfDataStops()
      @_req.write("1")


  close: ->
    return if @_status is NylasLongConnection.Status.Closed
    @setStatus(NylasLongConnection.Status.Closed)
    @cleanup()

  closeIfDataStops: =>
    clearTimeout(@_pingTimeout) if @_pingTimeout
    @_pingTimeout = setTimeout =>
      @_pingTimeout = null
      @close()
    , 15 * 1000

  end: ->
    @setStatus(NylasLongConnection.Status.Ended)
    @cleanup()

  cleanup: ->
    clearInterval(@_pingTimeout) if @_pingTimeout
    @_pingTimeout = null
    @_buffer = ''
    if @_req
      @_req.end()
      @_req.abort()
      @_req = null

module.exports = NylasLongConnection
