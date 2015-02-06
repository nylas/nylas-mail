_ = require 'underscore-plus'
request = require 'request'
Actions = require './actions'
{APIError} = require './errors'
DatabaseStore = require './stores/database-store'
InboxLongConnection = require './inbox-long-connection'
{modelFromJSON, modelClassMap} = require './models/utils'
async = require 'async'

class InboxAPI

  constructor: ->
    @APILongConnections = {}
    atom.config.onDidChange('inbox.env', @_onConfigChanged)
    atom.config.onDidChange('inbox.token', @_onConfigChanged)
    @_onConfigChanged()
    @

  _onConfigChanged: =>
    @APIToken = atom.config.get('inbox.token')
    env = atom.config.get('inbox.env')
    if env in ['production']
      @AppID = 'c96gge1jo29pl2rebcb7utsbp'
      @APIRoot = 'https://api.inboxapp.com'
    else if env in ['staging', 'development']
      @AppID = '54miogmnotxuo5st254trcmb9'
      @APIRoot = 'https://api-staging.inboxapp.com'
    console.log("Inbox API Root: #{@APIRoot}")

    if @APIToken && (atom.state.mode == 'editor')
      @makeRequest
        path: "/n"
        returnsModel: true
        success: =>
          @_startLongPolling()
        error: =>
          @_startLongPolling()

  _startLongPolling: ->
    return unless atom.state.mode == 'editor'
    return if atom.getLoadSettings().isSpec

    DatabaseStore = require './stores/database-store'
    Namespace = require './models/namespace'
    DatabaseStore.findAll(Namespace).then (namespaces) =>
      namespaces.forEach (namespace) =>
        connection = new InboxLongConnection(@, namespace.id)
        @APILongConnections[namespace.id] = connection

        if !connection.hasCursor()
          @getThreads(namespace.id)
          @getCalendars(namespace.id)

        connection.onStateChange (state) ->
          Actions.longPollStateChanged(state)
          if state == InboxLongConnection.State.Connected
            Actions.restartTaskQueue()
        connection.onDelta (delta) =>
          @_handleLongPollingChange(namespace.id, delta)
          Actions.restartTaskQueue()
        connection.start()
    .catch (error) -> console.error(error)

  # Delegates to node's request object.
  # On success, it will call the passed in success callback with options.
  # On error it will create a new APIError object that wraps the error,
  # response, and body.
  #
  # Options:
  #   {Any option that node's request takes}
  #   returnsModel - boolean to determine if the response should be
  #                  unpacked into an Inbox data wrapper
  #   success: (body) -> callback gets passed the returned json object
  #   error: (apiError) -> the error callback gets passed an Inbox
  #                        APIError object.
  makeRequest: (options={}) ->
    return if atom.getLoadSettings().isSpec
    return console.log('Cannot make Inbox request without auth token.') unless @APIToken
    options.method ?= 'GET'
    options.url ?= "#{@APIRoot}#{options.path}" if options.path
    options.body ?= {} unless options.formData
    options.json ?= true
    options.auth = {'user': @APIToken, 'pass': '', sendImmediately: true}
    options.error ?= @_defaultErrorCallback

    request options, (error, response, body) =>
      Actions.didMakeAPIRequest({request: options, response: response})
      if error? or response.statusCode > 299
        options.error(new APIError({error:error, response:response, body:body}))
      else
        if _.isString body
          try
            body = JSON.parse(body)
          catch error
            options.error(new APIError({error:error, response:response, body:body}))
        @_handleModelResponse(body) if options.returnsModel
        options.success(body) if options.success

  _handleLongPollingChange: (namespaceId, delta) ->
    return if delta.object == 'contact'
    return if delta.object == 'event'

    @_shouldAcceptModel(delta.object, delta.attributes).then =>
      if delta.event == 'create'
        @_handleModelResponse(delta.attributes)
      else if delta.event == 'modify'
        @_handleModelResponse(delta.attributes)
      else if delta.event == 'delete'
        klass = modelClassMap[delta.object]
        return unless klass
        DatabaseStore.find(klass, delta.id).then (model) ->
          DatabaseStore.unpersistModel(model)
    .catch (rejectionReason) ->
      console.log("Delta to '#{delta.event}' a '#{delta.object}' was ignored:",
        rejectionReason, delta)

  _defaultErrorCallback: (apiError) ->
    console.error("Unhandled Inbox API Error:", apiError.message, apiError)

  _handleModelResponse: (json) ->
    throw new Error("handleModelResponse with no JSON provided") unless json
    json = [json] unless json instanceof Array

    async.filter json
    , (json, callback) =>
      @_shouldAcceptModel(json.object, json).then((-> callback(true)), (-> callback(false)))
    , (json) ->
      # Save changes to the database, which will generate actions
      # that our views are observing.
      objects = []
      for objectJSON in json
        objects.push(modelFromJSON(objectJSON))
      DatabaseStore.persistModels(objects) if objects.length > 0

  _shouldAcceptModel: (classname, model = null) ->
    switch classname
      when "message"
        return Promise.resolve() unless model && model.draft
        return new Promise (resolve, reject) ->
          Message = require './models/message'
          DatabaseStore = require './stores/database-store'
          DatabaseStore.findBy(Message, {version: model.version}).then (draft) ->
            if draft?
              reject(new Error("Already a draft with version #{model.version}"))
            else
              resolve()
      else
        return Promise.resolve()

  getThreadsForSearch: (namespaceId, query, callback) ->
    throw (new Error "getThreadsForSearch requires namespaceId") unless namespaceId
    @makeRequest
      method: 'POST'
      path: "/n/#{namespaceId}/threads/search"
      body: {"query": query}
      json: true
      returnsModel: false
      success: (json) ->
        objects = []
        for resultJSON in json.results
          obj = modelFromJSON(resultJSON.object)
          obj.relevance = resultJSON.relevance
          objects.push(obj)

        DatabaseStore.persistModels(objects) if objects.length > 0
        callback(objects)

  # TODO remove from inbox-api and put in individual stores. The general
  # API abstraction should not need to know about threads and calendars.
  # They're still here because of their dependency in
  # _postLaunchStartStreaming
  getThreads: (namespaceId, params) ->
    @getCollection(namespaceId, 'threads', params)

  getCalendars: (namespaceId) ->
    @getCollection(namespaceId, 'calendars', {})

  getCollection: (namespaceId, collection, params={}) ->
    throw (new Error "getCollection requires namespaceId") unless namespaceId
    @makeRequest
      path: "/n/#{namespaceId}/#{collection}"
      qs: params
      returnsModel: true

module.exports = InboxAPI
