_ = require 'underscore'
request = require 'request'
Utils = require './models/utils'
Actions = require './actions'
{APIError} = require './errors'
PriorityUICoordinator = require '../priority-ui-coordinator'
DatabaseStore = require './stores/database-store'
async = require 'async'

# A 0 code is when an error returns without a status code. These are
# things like "ESOCKETTIMEDOUT"
TimeoutErrorCode = 0
PermanentErrorCodes = [400, 404, 500, TimeoutErrorCode]
CancelledErrorCode = -123
SampleTemporaryErrorCode = 504

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

    @options.timeout ?= 15000

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

    requestId = Utils.generateTempId()
    new Promise (resolve, reject) =>
      @options.startTime = Date.now()
      Actions.willMakeAPIRequest({request: @options, requestId: requestId})
      req = request @options, (error, response, body) =>
        Actions.didMakeAPIRequest({request: @options, response: response, error: error, requestId: requestId})
        PriorityUICoordinator.settle.then =>
          if error or response.statusCode > 299
            # Some errors (like socket errors and some types of offline
            # errors) return with a valid `error` object but no `response`
            # object (and therefore no `statusCode`. To normalize all of
            # this, we inject our own offline status code so people down
            # the line can have a more consistent interface.
            if not response?.statusCode
              response ?= {}
              response.statusCode = TimeoutErrorCode
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

  TimeoutErrorCode: TimeoutErrorCode
  PermanentErrorCodes: PermanentErrorCodes
  CancelledErrorCode: CancelledErrorCode
  SampleTemporaryErrorCode: SampleTemporaryErrorCode

  constructor: ->
    @_workers = []
    @_optimisticChangeTracker = new NylasAPIOptimisticChangeTracker()

    atom.config.onDidChange('env', @_onConfigChanged)
    atom.config.onDidChange('tokens', @_onConfigChanged)
    @_onConfigChanged()

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

    if atom.isWorkWindow() and not _.isEqual(prev, current)
      @APITokens.forEach (token) =>
        @makeRequest
          path: "/account"
          auth: {'user': token, 'pass': '', sendImmediately: true}
          returnsModel: true

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

    if components.length is 3
      [root, collection, klassId] = components
      klass = @_apiObjectToClassMap[collection[0..-2]] # Warning: threads => thread

    if klass and klassId and klassId.length > 0
      unless atom.inSpecMode()
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

  # Returns a Promise that resolves when any parsed out models (if any)
  # have been created and persisted to the database.
  #
  _handleModelResponse: (jsons) ->
    if not jsons
      return Promise.reject(new Error("handleModelResponse with no JSON provided"))

    jsons = [jsons] unless jsons instanceof Array
    if jsons.length is 0
      return Promise.resolve([])

    type = jsons[0].object
    klass = @_apiObjectToClassMap[type]
    if not klass
      console.warn("NylasAPI::handleModelResponse: Received unknown API object type: #{type}")
      return Promise.resolve([])

    # Step 1: Make sure the list of objects contains no duplicates, which cause
    # problems downstream when we try to write to the database.
    uniquedJSONs = _.uniq jsons, false, (model) -> model.id
    if uniquedJSONs.length < jsons.length
      console.warn("NylasAPI.handleModelResponse: called with non-unique object set. Maybe an API request returned the same object more than once?")

    # Step 2: Filter out any objects locked by the optimistic change tracker.
    unlockedJSONs = _.filter uniquedJSONs, (json) =>
      if @_optimisticChangeTracker.acceptRemoteChangesTo(klass, json.id) is false
        json._delta?.ignoredBecause = "This model is locked by the optimistic change tracker"
        return false
      return true

    # Step 3: Retrieve any existing models from the database for the given IDs.
    ids = _.pluck(unlockedJSONs, 'id')
    DatabaseStore = require './stores/database-store'
    DatabaseStore.findAll(klass).where(klass.attributes.id.in(ids)).then (models) ->
      existingModels = {}
      existingModels[model.id] = model for model in models

      responseModels = []
      changedModels = []

      # Step 4: Merge the response data into the existing data for each model,
      # skipping changes when we already have the given version
      unlockedJSONs.forEach (json) =>
        model = existingModels[json.id]

        isSameOrNewerVersion = model and model.version? and json.version? and model.version >= json.version
        isAlreadySent = model and model.draft is false and json.draft is true

        unless isSameOrNewerVersion or isAlreadySent
          model ?= new klass()
          model.fromJSON(json)
          changedModels.push(model)
        responseModels.push(model)

      # Step 5: Save models that have changed, and then return all of the models
      # that were in the response body.
      DatabaseStore.persistModels(changedModels).then ->
        return Promise.resolve(responseModels)

  _apiObjectToClassMap:
    "file": require('./models/file')
    "event": require('./models/event')
    "label": require('./models/label')
    "folder": require('./models/folder')
    "thread": require('./models/thread')
    "draft": require('./models/message')
    "account": require('./models/account')
    "message": require('./models/message')
    "contact": require('./models/contact')
    "calendar": require('./models/calendar')
    "metadata": require('./models/metadata')

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
