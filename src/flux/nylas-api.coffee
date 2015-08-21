_ = require 'underscore'
request = require 'request'
Actions = require './actions'
{APIError} = require './errors'
PriorityUICoordinator = require '../priority-ui-coordinator'
DatabaseStore = require './stores/database-store'
NylasSyncWorker = require './nylas-sync-worker'
NylasLongConnection = require './nylas-long-connection'
DatabaseObjectRegistry = require '../database-object-registry'
async = require 'async'

PermanentErrorCodes = [400, 404, 500]
CancelledErrorCode = -123

# This is lazy-loaded
AccountStore = null


class NylasAPIOptimisticChangeTracker
  constructor: ->
    @_locks = {}

  acceptRemoteChangesTo: (klass, id) ->
    key = "#{klass.name}-#{id}"
    @_locks[key] is undefined

  increment: (klass, id) ->
    key = "#{klass.name}-#{id}"
    @_locks[key] ?= 0
    @_locks[key] += 1

  decrement: (klass, id) ->
    key = "#{klass.name}-#{id}"
    return unless @_locks[key]?
    @_locks[key] -= 1
    if @_locks[key] <= 0
      delete @_locks[key]

  print: ->
    console.log("The following models are locked:")
    console.log(@_locks)

class NylasAPIRequest

  constructor: (@api, @options) ->
    @options.method ?= 'GET'
    @options.url ?= "#{@api.APIRoot}#{@options.path}" if @options.path
    @options.json ?= true

    unless @options.method is 'GET' or @options.formData
      @options.body ?= {}
    @

  run: ->
    if not @options.auth
      if not @options.accountId
        err = new APIError(statusCode: 400, body: "Cannot make Nylas request without specifying `auth` or an `accountId`.")
        return Promise.reject(err)

      token = @api.accessTokenForAccountId(@options.accountId)
      if not token
        err = new APIError(statusCode: 400, body: "Cannot make Nylas request for account #{@options.accountId} auth token.")
        return Promise.reject(err)

      @options.auth =
        user: token
        pass: ''
        sendImmediately: true

    new Promise (resolve, reject) =>
      req = request @options, (error, response, body) =>
        PriorityUICoordinator.settle.then =>
          Actions.didMakeAPIRequest({request: @options, response: response})

          if error or response.statusCode > 299
            apiError = new APIError({error, response, body, requestOptions: @options})
            @options.error?(apiError)
            reject(apiError)
          else
            @options.success?(body)
            resolve(body)
      req.on 'abort', ->
        cancelled = new APIError
          statusCode: CancelledErrorCode,
          body: 'Request Aborted'
        reject(cancelled)

      @options.started?(req)


class NylasAPI

  PermanentErrorCodes: PermanentErrorCodes
  CancelledErrorCode: CancelledErrorCode

  constructor: ->
    @_workers = []
    @_optimisticChangeTracker = new NylasAPIOptimisticChangeTracker()

    atom.config.onDidChange('env', @_onConfigChanged)
    atom.config.onDidChange('tokens', @_onConfigChanged)
    @_onConfigChanged()

    if atom.isMainWindow()
      AccountStore = require './stores/account-store'
      AccountStore.listen(@_onAccountsChanged, @)
      @_onAccountsChanged()

  _onConfigChanged: =>
    prev = {@AppID, @APIRoot, @APITokens}

    tokens = atom.config.get('tokens') || []
    tokens = tokens.filter (t) -> t.provider is 'nylas'
    @APITokens = tokens.map (t) -> t.access_token

    env = atom.config.get('env')
    if env in ['production']
      @AppID = 'c96gge1jo29pl2rebcb7utsbp'
      @APIRoot = 'https://api.nylas.com'
    else if env in ['staging', 'development']
      @AppID = '54miogmnotxuo5st254trcmb9'
      @APIRoot = 'https://api-staging.nylas.com'
    else if env in ['experimental']
      @AppID = 'c5dis00do2vki9ib6hngrjs18'
      @APIRoot = 'https://api-staging-experimental.nylas.com'
    else if env in ['local']
      @AppID = 'n/a'
      @APIRoot = 'http://localhost:5555'

    current = {@AppID, @APIRoot, @APITokens}

    if atom.isMainWindow() and not _.isEqual(prev, current)
      @APITokens.forEach (token) =>
        @makeRequest
          path: "/account"
          auth: {'user': token, 'pass': '', sendImmediately: true}
          returnsModel: true

  _onAccountsChanged: ->
    return if atom.inSpecMode()

    AccountStore = require './stores/account-store'
    accounts = AccountStore.items()
    workers = _.map(accounts, @workerForAccount)

    # Stop the workers that are not in the new workers list.
    # These accounts are no longer in our database, so we shouldn't
    # be listening.
    old = _.without(@_workers, workers...)
    worker.cleanup() for worker in old

    @_workers = workers

  workers: =>
    @_workers

  workerForAccount: (account) =>
    worker = _.find @_workers, (c) -> c.account().id is account.id
    return worker if worker

    worker = new NylasSyncWorker(@, account)
    connection = worker.connection()

    connection.onStateChange (state) ->
      Actions.longPollStateChanged({accountId: account.id, state: state})
      if state == NylasLongConnection.State.Connected
        ## TODO use OfflineStatusStore
        Actions.longPollConnected()
      else
        ## TODO use OfflineStatusStore
        Actions.longPollOffline()

    connection.onDeltas (deltas) =>
      PriorityUICoordinator.settle.then =>
        @_handleDeltas(deltas)

    @_workers.push(worker)
    worker.start()
    worker

  _cleanupAccountWorkers: ->
    for worker in @_workers
      worker.cleanup()
    @_workers = []


  # Delegates to node's request object.
  # On success, it will call the passed in success callback with options.
  # On error it will create a new APIError object that wraps the error,
  # response, and body.
  #
  # Options:
  #   {Any option that node's request takes}
  #   returnsModel - boolean to determine if the response should be
  #                  unpacked into an Nylas data wrapper
  #   success: (body) -> callback gets passed the returned json object
  #   error: (apiError) -> the error callback gets passed an Nylas
  #                        APIError object.
  #
  # Returns a Promise, which resolves or rejects in the success / error
  # scenarios, respectively.
  #
  makeRequest: (options={}) ->
    if atom.getLoadSettings().isSpec
      return Promise.resolve()

    success = (body) =>
      if options.beforeProcessing
        body = options.beforeProcessing(body)
      if options.returnsModel
        @_handleModelResponse(body).then (objects) ->
          return Promise.resolve(body)
      Promise.resolve(body)

    error = (err) =>
      handlePromise = Promise.resolve()
      if err.response
        if err.response.statusCode is 404 and options.returnsModel
          handlePromise = @_handleModel404(options.url)
        if err.response.statusCode is 401
          handlePromise = @_handle401(options.url)
      handlePromise.finally ->
        Promise.reject(err)

    req = new NylasAPIRequest(@, options)
    req.run().then(success, error)

  # If we make a request that `returnsModel` and we get a 404, we want to handle
  # it intelligently and in a centralized way. This method identifies the object
  # that could not be found and purges it from local cache.
  #
  # Handles: /account/<nid>/<collection>/<id>
  #
  _handleModel404: (modelUrl) ->
    url = require('url')
    {pathname, query} = url.parse(modelUrl, true)
    components = pathname.split('/')

    if components.length is 5
      [root, ns, nsId, collection, klassId] = components
      klass = DatabaseObjectRegistry.get(collection[0..-2]) # Warning: threads => thread

    if klass and klassId and klassId.length > 0
      console.warn("Deleting #{klass.name}:#{klassId} due to API 404")
      DatabaseStore.find(klass, klassId).then (model) ->
        if model
          return DatabaseStore.unpersistModel(model)
        else return Promise.resolve()
    else
      return Promise.resolve()

  _handle401: (modelUrl) ->
    Actions.postNotification
      type: 'error'
      tag: '401'
      sticky: true
      message: "Nylas can no longer authenticate with your mail provider. You will not be able to send or receive mail. Please log out and sign in again.",
      icon: 'fa-sign-out'
      actions: [{
        label: 'Log Out'
        id: '401:logout'
      }]

    unless @_notificationUnlisten
      handler = ({notification, action}) ->
        if action.id is '401:logout'
          atom.logout()
      @_notificationUnlisten = Actions.notificationActionTaken.listen(handler, @)

    return Promise.resolve()

  _handleDeltas: (deltas) ->
    Actions.longPollReceivedRawDeltas(deltas)

    # Create a (non-enumerable) reference from the attributes which we carry forward
    # back to their original deltas. This allows us to mark the deltas that the
    # app ignores later in the process.
    deltas.forEach (delta) ->
      if delta.attributes
        Object.defineProperty(delta.attributes, '_delta', { get: -> delta })

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
          klass = DatabaseObjectRegistry.get(delta.object)
          return unless klass
          DatabaseStore.find(klass, delta.id).then (model) ->
            return Promise.resolve() unless model
            return DatabaseStore.unpersistModel(model)

        Promise.settle(destroyPromises).then =>
          Actions.longPollProcessedDeltas()

  # Returns a Promsie that resolves when any parsed out models (if any)
  # have been created and persisted to the database.
  _handleModelResponse: (jsons) ->
    if not jsons
      return Promise.reject(new Error("handleModelResponse with no JSON provided"))

    jsons = [jsons] unless jsons instanceof Array
    if jsons.length is 0
      return Promise.resolve([])

    # Run a few assertions to make sure we're not going to run into problems
    uniquedJSONs = _.uniq jsons, false, (model) -> model.id
    if uniquedJSONs.length < jsons.length
      console.warn("NylasAPI.handleModelResponse: called with non-unique object set. Maybe an API request returned the same object more than once?")

    type = jsons[0].object
    name = @_apiObjectToClassnameMap[type]
    if not name
      console.error("Unrecoganized API object type: #{type}")
      return Promise.resolve([])

    accepted = Promise.resolve(uniquedJSONs)
    if type is "thread"
      Thread = require './models/thread'
      accepted = @_acceptableModelsInResponse(Thread, uniquedJSONs)
    else if type is "draft"
      Message = require './models/message'
      accepted = @_acceptableModelsInResponse(Message, uniquedJSONs)

    mapper = (json) ->
      return DatabaseObjectRegistry.deserialize(name, json)

    accepted.map(mapper).then (objects) ->
      DatabaseStore.persistModels(objects).then ->
        return Promise.resolve(objects)

  _apiObjectToClassnameMap:
    "file": "File"
    "event": "Event"
    "label": "Label"
    "folder": "Folder"
    "thread": "Thread"
    "draft": "Message"
    "message": "Message"
    "contact": "Contact"
    "calendar": "Calendar"
    "metadata": "Metadata"
    "namespace": "Namespace"

  _acceptableModelsInResponse: (klass, jsons) ->
    # Filter out models that are locked by pending optimistic changes
    accepted = jsons.filter (json) =>
      if @_optimisticChangeTracker.acceptRemoteChangesTo(klass, json.id) is false
        json._delta?.ignoredBecause = "This model is locked by the optimistic change tracker"
        return false
      return true

    # Filter out models that already have newer versions in the local cache
    ids = _.pluck(accepted, 'id')
    DatabaseStore = require './stores/database-store'
    DatabaseStore.findVersions(klass, ids).then (versions) ->
      accepted = accepted.filter (json) ->
        if json.version and versions[json.id] >= json.version
          json._delta?.ignoredBecause = "This version (#{json.version}) is not newer. Already have (#{versions[json.id]})"
          return false
        return true
      Promise.resolve(accepted)

  getThreads: (accountId, params = {}, requestOptions = {}) ->
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
    @getCollection(accountId, 'threads', params, requestOptions)

  getCollection: (accountId, collection, params={}, requestOptions={}) ->
    throw (new Error "getCollection requires accountId") unless accountId
    @makeRequest _.extend requestOptions,
      path: "/#{collection}"
      accountId: accountId
      qs: params
      returnsModel: true

  incrementOptimisticChangeCount: (klass, id) ->
    @_optimisticChangeTracker.increment(klass, id)

  decrementOptimisticChangeCount: (klass, id) ->
    @_optimisticChangeTracker.decrement(klass, id)

  tokenObjectForAccountId: (aid) ->
    AccountStore = require './stores/account-store'
    accounts = AccountStore.items() || []
    account = _.find accounts, (acct) -> acct.id is aid
    return null unless account

    tokens = atom.config.get('tokens') || []
    token = _.find tokens, (t) -> t.provider is 'nylas' and t.identifier is account.emailAddress
    return token

  accessTokenForAccountId: (aid) ->
    @tokenObjectForAccountId(aid)?.access_token

module.exports = new NylasAPI()
