_ = require 'underscore'
{NylasAPI, N1CloudAPI, Actions, DatabaseStore, NylasSyncStatusStore, NylasLongConnection} = require 'nylas-exports'
LocalSyncDeltaConnection = require('./local-sync-delta-connection').default
ContactRankingsCache = require './contact-rankings-cache'

INITIAL_PAGE_SIZE = 30
MAX_PAGE_SIZE = 100

# BackoffTimer is a small helper class that wraps setTimeout. It fires the function
# you provide at a regular interval, but backs off each time you call `backoff`.
#
class BackoffTimer
  constructor: (@fn) ->
    @resetDelay()

  cancel: =>
    clearTimeout(@_timeout) if @_timeout
    @_timeout = null

  backoff: (delay) =>
    @_delay = delay ? Math.min(@_delay * 1.7, 5 * 1000 * 60) # Cap at 5 minutes
    # Add "full" jitter (see: https://www.awsarchitectureblog.com/2015/03/backoff.html)
    @_actualDelay = Math.random() * @_delay
    if not NylasEnv.inSpecMode()
      console.log("Backing off after sync failure. Will retry in #{Math.floor(@_actualDelay / 1000)} seconds.")

  start: =>
    clearTimeout(@_timeout) if @_timeout
    @_timeout = setTimeout =>
      @_timeout = null
      @fn()
    , @_actualDelay

  resetDelay: =>
    @_delay = 2 * 1000
    @_actualDelay = Math.random() * @_delay

  getCurrentDelay: =>
    @_delay


module.exports =
class NylasSyncWorker

  constructor: (api, account) ->
    @_account = account

    # indirection needed so resumeFetches can be spied on
    @_resumeTimer = new BackoffTimer => @resume()
    @_refreshingCaches = [new ContactRankingsCache(account.id)]

    @_terminated = false
    @_connection = new LocalSyncDeltaConnection(api, account.id, {
      isReady: => @_state isnt null
      getCursor: =>
        return null if @_state is null
        @_state.cursor || NylasEnv.config.get("nylas.#{@_account.id}.cursor")
      setCursor: (val) =>
        @_state.cursor = val
        @writeState()
      onStatusChanged: (status, statusCode) =>
        @_state.longConnectionStatus = status
        if status is NylasLongConnection.Status.Closed
          # Make the delay 30 seconds if we get a 403
          delay = 30 * 1000 if statusCode is 403
          @_backoff(delay)
        if status is NylasLongConnection.Status.Connected
          @_resumeTimer.resetDelay()
        @writeState()
    })

    @_unlisten = Actions.retrySync.listen(@_onRetrySync, @)

    @_state = null
    DatabaseStore.findJSONBlob("NylasSyncWorker:#{@_account.id}").then (json) =>
      @_state = json ? {}
      for key in NylasSyncStatusStore.ModelsForSync
        @_state[key].busy = false if @_state[key]
      @resume()

    @

  account: ->
    @_account

  connection: ->
    @_connection

  state: ->
    @_state

  busy: ->
    return false unless @_state
    for key, state of @_state
      if state.busy
        return true
    false

  start: ->
    @_resumeTimer.start()
    @_connection.start()
    @_refreshingCaches.map (c) -> c.start()
    @resume()

  cleanup: ->
    @_unlisten?()
    @_resumeTimer.cancel()
    @_connection.end()
    @_refreshingCaches.map (c) -> c.end()
    @_terminated = true
    @

  resume: =>
    return unless @_state

    @_connection.start()

    # Stop the timer. If one or more network requests fails during the
    # fetch process we'll backoff and restart the timer.
    @_resumeTimer.cancel()

    needed = [
      {model: 'threads'},
      {model: 'messages', maxFetchCount: 5000}
      {model: 'folders', initialPageSize: 1000}
      {model: 'labels', initialPageSize: 1000}
      {model: 'drafts'},
      {model: 'contacts'},
      {model: 'calendars'},
      {model: 'events'},
    ].filter(@_shouldFetchCollection)

    return if needed.length is 0

    @_fetchMetadata().then(() => Promise.each(needed, @_fetchCollection))

  _fetchMetadata: (offset = 0) =>
    limit = 200
    N1CloudAPI.makeRequest
      accountId: @_account.id
      returnsModel: false
      path: "/metadata"
      qs: {limit, offset}
    .then((data) =>
      return if @_terminated
      for metadatum in data
        @_metadata[metadatum.object_id] ?= []
        @_metadata[metadatum.object_id].push(metadatum)
      if data.length is limit
        return @_fetchMetadata(offset + limit)
      else
        console.log("Retrieved #{offset + data.length} metadata objects")
        return Promise.resolve()
    ).catch(() =>
      return if @_terminated
      @_backoff()
    )

  _shouldFetchCollection: ({model} = {}) =>
    return false unless @_state
    state = @_state[model] ? {}

    return false if state.complete
    return false if state.busy
    return true

  _fetchCollection: ({model, initialPageSize, maxFetchCount} = {}) ->
    initialPageSize ?= INITIAL_PAGE_SIZE
    state = @_state[model] ? {}
    state.complete = false
    state.error = null
    state.busy = true
    state.fetched ?= 0
    state.count ?= 0

    if state.lastRequestRange
      {limit, offset} = state.lastRequestRange
      if state.fetched + limit > maxFetchCount
        limit = maxFetchCount - state.fetched
      state.lastRequestRange = null
      @_fetchCollectionPage(model, {limit, offset}, {maxFetchCount})
    else
      limit = initialPageSize
      if state.fetched + limit > maxFetchCount
        limit = maxFetchCount - state.fetched
      @_fetchCollectionPage(model, {
        limit: limit,
        offset: 0
      }, {maxFetchCount})

    @_state[model] = state
    @writeState()

  _fetchCollectionPage: (model, params = {}, options = {}) ->
    requestStartTime = Date.now()
    requestOptions =
      metadataToAttach: @_metadata

      error: (err) =>
        return if @_terminated
        @_onFetchCollectionPageError(model, params, err)

      success: (json) =>
        return if @_terminated

        if model in ["labels", "folders"] and @_hasNoInbox(json)
          @_onFetchCollectionPageError(model, params, "No inbox in #{model}")
          return

        lastReceivedIndex = params.offset + json.length
        moreToFetch = if options.maxFetchCount
          json.length is params.limit and lastReceivedIndex < options.maxFetchCount
        else
          json.length is params.limit

        if moreToFetch
          nextParams = _.extend({}, params, {offset: lastReceivedIndex})
          limit = Math.min(Math.round(params.limit * 1.5), MAX_PAGE_SIZE)
          if options.maxFetchCount
            limit = Math.min(limit, options.maxFetchCount - lastReceivedIndex)
          nextParams.limit = limit
          nextDelay = Math.max(0, 1500 - (Date.now() - requestStartTime))
          setTimeout(( => @_fetchCollectionPage(model, nextParams, options)), nextDelay)

        @updateTransferState(model, {
          fetched: lastReceivedIndex,
          busy: moreToFetch,
          complete: !moreToFetch,
          lastRequestRange: {offset: params.offset, limit: params.limit}
          error: null,
        })

    if model is 'threads'
      NylasAPI.getThreads(@_account.id, params, requestOptions)
    else
      NylasAPI.getCollection(@_account.id, model, params, requestOptions)

  # It's occasionally possible for the NylasAPI's labels or folders
  # endpoint to not return an "inbox" label. Since that's a core part of
  # the app and it doesn't function without it, keep retrying until we see
  # it.
  _hasNoInbox: (json) ->
    return not _.any(json, (obj) -> obj.name is "inbox")

  _onFetchCollectionPageError: (model, params, err) ->
    @_backoff()
    @updateTransferState(model, {
      busy: false,
      complete: false,
      error: err.toString()
      lastRequestRange: {offset: params.offset, limit: params.limit}
    })

  _backoff: (delay) =>
    @_resumeTimer.backoff(delay)
    @_resumeTimer.start()
    @_state.nextRetryDelay = @_resumeTimer.getCurrentDelay()
    @_state.nextRetryTimestamp = Date.now() + @_state.nextRetryDelay

  updateTransferState: (model, updatedKeys) ->
    @_state[model] = _.extend(@_state[model], updatedKeys)
    @writeState()

  writeState: ->
    @_writeState ?= _.debounce =>
      DatabaseStore.inTransaction (t) =>
        t.persistJSONBlob("NylasSyncWorker:#{@_account.id}", @_state)
    ,100
    @_writeState()

  _onRetrySync: =>
    @_resumeTimer.resetDelay()
    @resume()

NylasSyncWorker.BackoffTimer = BackoffTimer
NylasSyncWorker.INITIAL_PAGE_SIZE = INITIAL_PAGE_SIZE
NylasSyncWorker.MAX_PAGE_SIZE = MAX_PAGE_SIZE
