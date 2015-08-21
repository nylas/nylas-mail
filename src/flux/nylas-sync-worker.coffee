_ = require 'underscore'
NylasLongConnection = require './nylas-long-connection'
DatabaseStore = require './stores/database-store'
{Publisher} = require './modules/reflux-coffee'
CoffeeHelpers = require './coffee-helpers'

PAGE_SIZE = 250

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
    if not atom.inSpecMode()
      console.log("Backing off after sync failure. Will retry in #{Math.floor(@_delay / 1000)} seconds.")

  start: =>
    clearTimeout(@_timeout) if @_timeout
    @_timeout = setTimeout =>
      @_timeout = null
      @fn()
    , @_delay


module.exports =
class NylasSyncWorker

  @include: CoffeeHelpers.includeModule
  @include Publisher

  constructor: (api, account) ->
    @_api = api
    @_account = account

    @_terminated = false
    @_connection = new NylasLongConnection(api, account.id)
    @_resumeTimer = new BackoffTimer =>
      # indirection needed so resumeFetches can be spied on
      @resumeFetches()

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
    @resumeFetches()

  cleanup: ->
    @_resumeTimer.cancel()
    @_connection.end()
    @_terminated = true
    @

  resumeFetches: =>
    return unless @_state

    # Stop the timer. If one or more network requests fails during the fetch process
    # we'll backoff and restart the timer.
    @_resumeTimer.cancel()

    @fetchCollection('threads')
    @fetchCollection('calendars')
    @fetchCollection('contacts')
    @fetchCollection('drafts')
    if @_account.usesLabels()
      @fetchCollection('labels')
    if @_account.usesFolders()
      @fetchCollection('folders')

  fetchCollection: (model, options = {}) ->
    return unless @_state
    return if @_state[model]?.complete and not options.force?
    return if @_state[model]?.busy

    @_state[model] =
      complete: false
      error: null
      busy: true
      count: 0
      fetched: 0
    @writeState()

    @fetchCollectionCount(model)
    @fetchCollectionPage(model, {offset: 0, limit: PAGE_SIZE})

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
    requestOptions =
      error: (err) =>
        return if @_terminated
        @_resumeTimer.backoff()
        @_resumeTimer.start()
        @updateTransferState(model, {busy: false, complete: false, error: err.toString()})
      success: (json) =>
        return if @_terminated
        lastReceivedIndex = params.offset + json.length
        if json.length is params.limit
          nextParams = _.extend({}, params, {offset: lastReceivedIndex})
          @fetchCollectionPage(model, nextParams)
          @updateTransferState(model, {fetched: lastReceivedIndex})
        else
          @updateTransferState(model, {fetched: lastReceivedIndex, busy: false, complete: true})

    if model is 'threads'
      @_api.getThreads(@_account.id, params, requestOptions)
    else
      @_api.getCollection(@_account.id, model, params, requestOptions)

  updateTransferState: (model, {busy, error, complete, fetched, count}) ->
    @_state[model] = _.defaults({busy, error, complete, fetched, count}, @_state[model])
    @writeState()

  writeState: ->
    @_writeState ?= _.debounce =>
      DatabaseStore.persistJSONObject("NylasSyncWorker:#{@_account.id}", @_state)
    ,100
    @_writeState()
    @trigger()

NylasSyncWorker.BackoffTimer = BackoffTimer
