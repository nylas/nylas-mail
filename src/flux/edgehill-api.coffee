_ = require 'underscore'
nodeRequest = require 'request'
Utils = require './models/utils'
Actions = require './actions'
{APIError} = require './errors'
DatabaseStore = require './stores/database-store'
PriorityUICoordinator = require '../priority-ui-coordinator'
async = require 'async'

# TODO: Fold this code into NylasAPI or create a base class
class EdgehillAPI

  constructor: ->
    atom.config.onDidChange('env', @_onConfigChanged)
    @_onConfigChanged()
    @

  _onConfigChanged: =>
    env = atom.config.get('env')
    if env is 'development'
      # @APIRoot = "http://localhost:5009"
      @APIRoot = "https://edgehill-dev.nylas.com"
    else if env is 'experimental'
      @APIRoot = "https://edgehill-experimental.nylas.com"
    else if env is 'staging'
      @APIRoot = "https://edgehill-staging.nylas.com"
    else
      @APIRoot = "https://edgehill.nylas.com"

  request: (options={}) ->
    return if atom.getLoadSettings().isSpec
    options.method ?= 'GET'
    options.url ?= "#{@APIRoot}#{options.path}" if options.path
    options.body ?= {} unless options.formData
    options.json = true

    auth = @_getCredentials()
    if not options.auth and auth
      options.auth =
        user: auth.username
        pass: auth.password
        sendImmediately: true

    options.error ?= @_defaultErrorCallback

    # This is to provide functional closure for the variable.
    rid = Utils.generateTempId()
    [rid].forEach (requestId) ->
      options.startTime = Date.now()
      Actions.willMakeAPIRequest({
        request: options,
        requestId: requestId
      })
      nodeRequest options, (error, response, body) ->
        Actions.didMakeAPIRequest({
          request: options,
          statusCode: response?.statusCode,
          error: error,
          requestId: requestId
        })
        PriorityUICoordinator.settle.then ->
          if error? or response.statusCode > 299
            options.error(new APIError({error:error, response:response, body:body, requestOptions: options}))
          else
            options.success(body) if options.success

  _getCredentials: ->
    atom.config.get('edgehill.credentials')

  _setCredentials: (credentials) ->
    atom.config.set('edgehill.credentials', credentials)

  _defaultErrorCallback: (apiError) ->
    console.error(apiError)

module.exports = new EdgehillAPI
