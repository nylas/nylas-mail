_ = require 'underscore'
{Actions, DatabaseStore} = require 'nylas-exports'
NylasLongConnection = require './nylas-long-connection'
ContactRankingsCache = require './contact-rankings-cache'

INITIAL_PAGE_SIZE = 30
MAX_PAGE_SIZE = 250

# BackoffTimer is a small helper class that wraps setTimeout. It fires the function
# you provide at a regular interval, but backs off each time you call `backoff`.
#
class BackoffTimer
  constructor: (@fn) ->
    @reset()

  cancel: =>
    clearTimeout(@_timeout) if @_timeout
    @_timeout = null

  reset: =>
    @cancel()
    @_delay = 20 * 1000

  backoff: =>
    @_delay = Math.min(@_delay * 1.4, 5 * 1000 * 60) # Cap at 5 minutes
    if not NylasEnv.inSpecMode()
      console.log("Backing off after sync failure. Will retry in #{Math.floor(@_delay / 1000)} seconds.")

  start: =>
    clearTimeout(@_timeout) if @_timeout
    @_timeout = setTimeout =>
      @_timeout = null
      @fn()
    , @_delay


module.exports =
class NylasSyncWorker

  constructor: (api, account) ->
    @_api = api
    @_account = account

    @_terminated = false
    @_connection = new NylasLongConnection(api, account.id)
    @_refreshingCaches = [new ContactRankingsCache(account.id)]
    @_resumeTimer = new BackoffTimer =>
      # indirection needed so resumeFetches can be spied on
      @resumeFetches()

    @_unlisten = Actions.retryInitialSync.listen(@_onRetryInitialSync, @)

    @_state = null
    DatabaseStore.findJSONObject("NylasSyncWorker:#{@_account.id}").then (json) =>
      @_state = json ? {}
      for model, modelState of @_state
        modelState.busy = false
      @resumeFetches()

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
    @resumeFetches()

  cleanup: ->
    @_unlisten?()
    @_resumeTimer.cancel()
    @_connection.end()
    @_refreshingCaches.map (c) -> c.end()
    @_terminated = true
    @

  resumeFetches: =>
    return unless @_state

    # Stop the timer. If one or more network requests fails during the fetch process
    # we'll backoff and restart the timer.
    @_resumeTimer.cancel()

    @fetchCollection('threads')
    if @_account.usesLabels()
      @fetchCollection('labels', {initialPageSize: 1000})
    if @_account.usesFolders()
      @fetchCollection('folders', {initialPageSize: 1000})
    @fetchCollection('drafts')
    @fetchCollection('contacts')
    @fetchCollection('calendars')
    @fetchCollection('events')

  fetchCollection: (model, options = {}) ->
    return unless @_state
    state = @_state[model] ? {}

    return if state.complete and not options.force?
    return if state.busy

    state.complete = false
    state.error = null
    state.busy = true
    state.fetched ?= 0

    if not state.count
      state.count = 0
      @fetchCollectionCount(model)

    if state.errorRequestRange
      {limit, offset} = state.errorRequestRange
      state.errorRequestRange = null
      @fetchCollectionPage(model, {limit, offset})
    else
      @fetchCollectionPage(model, {
        limit: options.initialPageSize ? INITIAL_PAGE_SIZE,
        offset: 0
      })

    @_state[model] = state
    @writeState()

  fetchCollectionCount: (model) ->
    @_api.makeRequest
      accountId: @_account.id
      path: "/#{model}"
      returnsModel: false
      qs:
        view: 'count'
      success: (response) =>
        return if @_terminated
        @updateTransferState(model, count: response.count)
      error: (err) =>
        return if @_terminated
        @_resumeTimer.backoff()
        @_resumeTimer.start()

  fetchCollectionPage: (model, params = {}) ->
    requestStartTime = Date.now()
    requestOptions =
      error: (err) =>
        return if @_terminated
        @_fetchCollectionPageError(model, params, err)

      success: (json) =>
        return if @_terminated

        if model in ["labels", "folders"] and @_hasNoInbox(json)
          @_fetchCollectionPageError(model, params, "No inbox in #{model}")
          return

        lastReceivedIndex = params.offset + json.length
        moreToFetch = json.length is params.limit

        if moreToFetch
          nextParams = _.extend({}, params, {offset: lastReceivedIndex})
          nextParams.limit = Math.min(Math.round(params.limit * 1.5), MAX_PAGE_SIZE)
          nextDelay = Math.max(0, 1000 - (Date.now() - requestStartTime))
          setTimeout(( => @fetchCollectionPage(model, nextParams)), nextDelay)

        @updateTransferState(model, {
          fetched: lastReceivedIndex,
          busy: moreToFetch,
          complete: !moreToFetch,
          error: null,
          errorRequestRange: null
        })

    if model is 'threads'
      @_api.getThreads(@_account.id, params, requestOptions)
    else
      @_api.getCollection(@_account.id, model, params, requestOptions)

  # It's occasionally possible for the NylasAPI's labels or folders
  # endpoint to not return an "inbox" label. Since that's a core part of
  # the app and it doesn't function without it, keep retrying until we see
  # it.
  _hasNoInbox: (json) ->
    return not _.any(json, (obj) -> obj.name is "inbox")

  _fetchCollectionPageError: (model, params, err) ->
    @_resumeTimer.backoff()
    @_resumeTimer.start()
    @updateTransferState(model, {
      busy: false,
      complete: false,
      error: err.toString()
      errorRequestRange: {offset: params.offset, limit: params.limit}
    })

  updateTransferState: (model, updatedKeys) ->
    @_state[model] = _.extend(@_state[model], updatedKeys)
    @writeState()

  writeState: ->
    @_writeState ?= _.debounce =>
      DatabaseStore.persistJSONObject("NylasSyncWorker:#{@_account.id}", @_state)
    ,100
    @_writeState()

  _onRetryInitialSync: =>
    @resumeFetches()

NylasSyncWorker.BackoffTimer = BackoffTimer
NylasSyncWorker.INITIAL_PAGE_SIZE = INITIAL_PAGE_SIZE
NylasSyncWorker.MAX_PAGE_SIZE = MAX_PAGE_SIZE
