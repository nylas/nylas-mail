_ = require 'underscore'
NylasLongConnection = require './nylas-long-connection'
DatabaseStore = require './stores/database-store'
{Publisher} = require './modules/reflux-coffee'
CoffeeHelpers = require './coffee-helpers'

PAGE_SIZE = 250

module.exports =
class NylasSyncWorker

  @include: CoffeeHelpers.includeModule
  @include Publisher

  constructor: (api, namespace) ->
    @_api = api
    @_namespace = namespace

    @_terminated = false
    @_connection = new NylasLongConnection(api, namespace.id)

    @_state = null
    DatabaseStore.findJSONObject("NylasSyncWorker:#{@_namespace.id}").then (json) =>
      @_state = json ? {}
      for model, modelState of @_state
        modelState.busy = false
      @resumeFetches()

    @

  namespace: ->
    @_namespace

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
    @_resumeTimer = setInterval(@resumeFetches, 20000)
    @_connection.start()
    @resumeFetches()

  cleanup: ->
    clearInterval(@_resumeTimer)
    @_connection.end()
    @_terminated = true
    @

  resumeFetches: =>
    return unless @_state
    @fetchCollection('threads')
    @fetchCollection('calendars')
    @fetchCollection('contacts')
    @fetchCollection('drafts')
    if @_namespace.usesLabels()
      @fetchCollection('labels')
    if @_namespace.usesFolders()
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
      path: "/n/#{@_namespace.id}/#{model}"
      returnsModel: false
      qs:
        view: 'count'
      success: (response) =>
        return if @_terminated
        @updateTransferState(model, count: response.count)
      error: (err) =>
        return if @_terminated

  fetchCollectionPage: (model, params = {}) ->
    requestOptions =
      error: (err) =>
        return if @_terminated
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
      @_api.getThreads(@_namespace.id, params, requestOptions)
    else
      @_api.getCollection(@_namespace.id, model, params, requestOptions)

  updateTransferState: (model, {busy, error, complete, fetched, count}) ->
    @_state[model] = _.defaults({busy, error, complete, fetched, count}, @_state[model])
    @writeState()

  writeState: ->
    @_writeState ?= _.debounce =>
      DatabaseStore.persistJSONObject("NylasSyncWorker:#{@_namespace.id}", @_state)
    ,100
    @_writeState()
    @trigger()
