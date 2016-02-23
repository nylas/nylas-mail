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
    NylasEnv.config.onDidChange('env', @_onConfigChanged)
    @_onConfigChanged()
    @

  _onConfigChanged: =>
    env = NylasEnv.config.get('env')
    if env is 'development'
      @APIRoot = "http://localhost:5009"
    else if env is 'experimental'
      @APIRoot = "https://edgehill-experimental.nylas.com"
    else if env is 'staging'
      @APIRoot = "https://n1-auth-staging.nylas.com"
    else
      @APIRoot = "https://n1-auth.nylas.com"

  request: (options={}) ->
    return if NylasEnv.getLoadSettings().isSpec
    options.method ?= 'GET'
    options.url ?= "#{@APIRoot}#{options.path}" if options.path
    options.body ?= {} unless options.formData
    options.json = true
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

  _defaultErrorCallback: (apiError) ->
    console.error(apiError)

module.exports = new EdgehillAPI
