_ = require 'underscore-plus'
InboxLongConnection = require './inbox-long-connection'

PAGE_SIZE = 500

module.exports =
class InboxSyncWorker

  constructor: (inbox, namespaceId) ->
    @_inbox = inbox
    @_namespaceId = namespaceId

    @_terminated = false
    @_connection = new InboxLongConnection(inbox, namespaceId)
    @_state = atom.config.get("inbox.#{namespaceId}.worker-state") ? {}
    @
  
  namespaceId: ->
    @_namespaceId

  connection: ->
    @_connection

  start: ->
    @_connection.start()
    @fetchCollection('threads')
    @fetchCollection('calendars')
    @fetchCollection('contacts')

  cleanup: ->
    @_connection.end()
    @_terminated = true
    @

  fetchCollection: (model, options = {}, callback) ->
    return if @_state[model]?.complete and not options.force?

    @_state[model] = {busy: true}
    @writeState()

    params =
      offset: 0
      limit: PAGE_SIZE
    @fetchCollectionPage(model, params, callback)

  fetchCollectionPage: (model, params = {}, callback) ->
    requestOptions =
      error: (err) =>
        return if @_terminated
        @_state[model] = {busy: false, error: err.toString()}
        @writeState()
        callback(err) if callback
      success: (json) =>
        return if @_terminated
        if json.length is params.limit
          params.offset = params.offset + json.length
          @fetchCollectionPage(model, params, callback)
        else
          @_state[model] = {complete: true}
          @writeState()
          callback() if callback

    if model is 'threads'
      @_inbox.getThreads(@_namespaceId, params, requestOptions)
    else
      @_inbox.getCollection(@_namespaceId, model, params, requestOptions)
  
  writeState: ->
    @_writeState ?= _.debounce =>
      atom.config.set("inbox.#{@_namespaceId}.worker-state", @_state)
    ,100
    @_writeState()
