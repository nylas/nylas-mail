_ = require 'underscore-plus'
NylasLongConnection = require './nylas-long-connection'

{Publisher} = require './modules/reflux-coffee'
CoffeeHelpers = require './coffee-helpers'

PAGE_SIZE = 250

module.exports =
class NylasSyncWorker

  @include: CoffeeHelpers.includeModule
  @include Publisher

  constructor: (api, namespaceId) ->
    @_api = api
    @_namespaceId = namespaceId

    @_terminated = false
    @_connection = new NylasLongConnection(api, namespaceId)
    @_state = atom.config.get("nylas.#{namespaceId}.worker-state") ? {}
    for model, modelState of @_state
      modelState.busy = false

    @

  namespaceId: ->
    @_namespaceId

  connection: ->
    @_connection

  state: ->
    @_state

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
    @fetchCollection('threads')
    @fetchCollection('calendars')
    @fetchCollection('contacts')
    @fetchCollection('files')

  fetchCollection: (model, options = {}) ->
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
      path: "/n/#{@_namespaceId}/#{model}"
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
      @_api.getThreads(@_namespaceId, params, requestOptions)
    else
      @_api.getCollection(@_namespaceId, model, params, requestOptions)

  updateTransferState: (model, {busy, error, complete, fetched, count}) ->
    @_state[model] = _.defaults({busy, error, complete, fetched, count}, @_state[model])
    @writeState()

  writeState: ->
    @_writeState ?= _.debounce =>
      atom.config.set("nylas.#{@_namespaceId}.worker-state", @_state)
    ,100
    @_writeState()
    @trigger()
