_ = require 'underscore'
nodeRequest = require 'request'
Utils = require './models/utils'
Actions = require './actions'
{APIError} = require './errors'
DatabaseStore = require './stores/database-store'
PriorityUICoordinator = require '../priority-ui-coordinator'
async = require 'async'


class SignupAPI

  constructor: ->
    atom.config.onDidChange('env', @_onConfigChanged)
    @_onConfigChanged()
    @

  _onConfigChanged: =>
    env = atom.config.get('env')
    if env is 'development'
      @APIRoot = "http://localhost:5000"
    else if env in ['experimental', 'staging']
      @APIRoot = "https://invite-staging.nylas.com"
    else
      @APIRoot = "https://invite.nylas.com"

  request: (options={}) ->
    return if atom.getLoadSettings().isSpec
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

  _onNetworkError: (err) =>
    errorMessage = err.message
    pageNumber = @state.pageNumber
    errorFieldNames = err.body?.missing_fields || err.body?.missing_settings

    if errorFieldNames
      {pageNumber, errorMessage} = @_stateForMissingFieldNames(errorFieldNames)
    if err.statusCode is -123 # timeout
      errorMessage = "Request timed out. Please try again."

    @setState
      pageNumber: pageNumber
      errorMessage: errorMessage
      errorFieldNames: errorFieldNames || []
      tryingToAuthenticate: false
    @_resize()

module.exports = new SignupAPI
