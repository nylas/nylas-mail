_ = require 'underscore-plus'
request = require 'request'
Actions = require './actions'
{APIError} = require './errors'
PriorityUICoordinator = require '../priority-ui-coordinator'
DatabaseStore = require './stores/database-store'
NamespaceStore = require './stores/namespace-store'
InboxSyncWorker = require './inbox-sync-worker'
InboxLongConnection = require './inbox-long-connection'
{modelFromJSON, modelClassMap} = require './models/utils'
async = require 'async'


class InboxAPI

  constructor: ->
    @_workers = []

    atom.config.onDidChange('env', @_onConfigChanged)
    atom.config.onDidChange('inbox.token', @_onConfigChanged)
    @_onConfigChanged()

    NamespaceStore.listen(@_onNamespacesChanged, @)
    @_onNamespacesChanged()
    @

  _onConfigChanged: =>
    prev = {@APIToken, @AppID, @APIRoot}

    @APIToken = atom.config.get('inbox.token')
    env = atom.config.get('env')
    if env in ['production']
      @AppID = 'c96gge1jo29pl2rebcb7utsbp'
      @APIRoot = 'https://api.nylas.com'
    else if env in ['staging', 'development']
      @AppID = '54miogmnotxuo5st254trcmb9'
      @APIRoot = 'https://api-staging.nylas.com'

    current = {@APIToken, @AppID, @APIRoot}

    if atom.state.mode is 'editor'
      if not @APIToken?
        @_cleanupNamespaceWorkers()

      if not _.isEqual(prev, current)
        @makeRequest
          path: "/n"
          returnsModel: true

  _onNamespacesChanged: ->
    return unless atom.state.mode is 'editor'
    return if atom.getLoadSettings().isSpec
    
    namespaces = NamespaceStore.items()
    workers = _.map(namespaces, @_workerForNamespace)

    # Stop the workers that are not in the new workers list.
    # These namespaces are no longer in our database, so we shouldn't
    # be listening.
    old = _.without(@_workers, workers...)
    worker.cleanup() for worker in old

    @_workers = workers

  _cleanupNamespaceWorkers: ->
    for worker in @_workers
      worker.cleanup()
    @_workers = []

  _workerForNamespace: (namespace) =>
    worker = _.find @_workers, (c) ->
      c.namespaceId() is namespace.id
    return worker if worker

    worker = new InboxSyncWorker(@, namespace.id)
    connection = worker.connection()

    connection.onStateChange (state) ->
      Actions.longPollStateChanged(state)
      if state == InboxLongConnection.State.Connected
        ## TODO use OfflineStatusStore
        Actions.longPollConnected()
      else
        ## TODO use OfflineStatusStore
        Actions.longPollOffline()

    connection.onDeltas (deltas) =>
      PriorityUICoordinator.settle.then =>
        @_handleDeltas(deltas)

    worker.start()
    worker

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
      PriorityUICoordinator.settle.then =>
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

  _handleDeltas: (deltas) ->
    Actions.longPollReceivedRawDeltas(deltas)
    console.log("Processing Deltas")

    # Group deltas by object type so we can mutate the cache efficiently.
    # NOTE: This code must not just accumulate creates, modifies and destroys
    # but also de-dupe them. We cannot call "persistModels(itemA, itemA, itemB)"
    # or it will throw an exception - use the last received copy of each model
    # we see.
    create = {}
    modify = {}
    destroy = []
    for delta in deltas
      if delta.event is 'create'
        create[delta.object] ||= {}
        create[delta.object][delta.attributes.id] = delta.attributes
      else if delta.event is 'modify'
        modify[delta.object] ||= {}
        modify[delta.object][delta.attributes.id] = delta.attributes
      else if delta.event is 'delete'
        destroy.push(delta)

    # Apply all the deltas to create objects. Gets promises for handling
    # each type of model in the `create` hash, waits for them all to resolve.
    create[type] = @_handleModelResponse(_.values(dict)) for type, dict of create
    Promise.props(create).then (created) =>
      # Apply all the deltas to modify objects. Gets promises for handling
      # each type of model in the `modify` hash, waits for them all to resolve.
      modify[type] = @_handleModelResponse(_.values(dict)) for type, dict of modify
      Promise.props(modify).then (modified) ->

        # Now that we've persisted creates/updates, fire an action
        # that allows other parts of the app to update based on new models
        # (notifications)
        if _.flatten(_.values(created)).length > 0
          Actions.didPassivelyReceiveNewModels(created)

        # Apply all of the deletions
        destroyPromises = destroy.map (delta) ->
          console.log(" - 1 #{delta.object} (#{delta.id})")
          klass = modelClassMap()[delta.object]
          return unless klass
          DatabaseStore.find(klass, delta.id).then (model) ->
            return Promise.resolve() unless model
            return DatabaseStore.unpersistModel(model)

        Promise.settle(destroyPromises)

  _defaultErrorCallback: (apiError) ->
    console.error("Unhandled Inbox API Error:", apiError.message, apiError)

  _handleModelResponse: (json) ->
    new Promise (resolve, reject) =>
      reject(new Error("handleModelResponse with no JSON provided")) unless json

      json = [json] unless json instanceof Array
      async.filter json
      , (item, filterCallback) =>
        @_shouldAcceptModel(item.object, item).then (accept) ->
          filterCallback(accept)
        .catch (e) ->
          filterCallback(false)
      , (json) ->
        # Save changes to the database, which will generate actions
        # that our views are observing.
        objects = []
        for objectJSON in json
          objects.push(modelFromJSON(objectJSON))
        if objects.length > 0
          DatabaseStore.persistModels(objects)
        resolve(objects)

  _shouldAcceptModel: (classname, model = null) ->
    return Promise.resolve(false) unless model

    if classname is "thread"
      Thread = require './models/thread'
      return @_shouldAcceptModelIfNewer(Thread, model)

    # For the time being, we never accept drafts from the server. This single
    # change ensures that all drafts in the system are authored locally. To
    # revert, change back to use _shouldAcceptModelIfNewer
    if classname is "draft" or model?.object is "draft"
      return Promise.resolve(false)

    Promise.resolve(true)

  _shouldAcceptModelIfNewer: (klass, model = null) ->
    new Promise (resolve, reject) ->
      DatabaseStore = require './stores/database-store'
      DatabaseStore.find(klass, model.id).then (existing) ->
        if existing and existing.version >= model.version
          resolve(false)
        else
          resolve(true)

  getThreads: (namespaceId, params = {}, requestOptions = {}) ->
    requestSuccess = requestOptions.success
    requestOptions.success = (json) =>
      messages = []
      for result in json
        if result.messages
          messages = messages.concat(result.messages)
      if messages.length > 0
        @_handleModelResponse(messages)
      if requestSuccess
        requestSuccess(json)

    params.view = 'expanded'
    @getCollection(namespaceId, 'threads', params, requestOptions)

  getCollection: (namespaceId, collection, params={}, requestOptions={}) ->
    throw (new Error "getCollection requires namespaceId") unless namespaceId
    @makeRequest _.extend requestOptions,
      path: "/n/#{namespaceId}/#{collection}"
      qs: params
      returnsModel: true

module.exports = InboxAPI
