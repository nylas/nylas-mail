nodeRequest = require 'request'
{Actions, Utils, APIError} = require 'nylas-exports'

class TokenAuthAPI

  constructor: ->
    NylasEnv.config.onDidChange('env', @_onConfigChanged)
    @_onConfigChanged()
    @

  _onConfigChanged: =>
    env = NylasEnv.config.get('env')
    if env is 'development'
      @APIRoot = "http://localhost:6001"
    else if env in ['experimental', 'staging']
      @APIRoot = "https://invite-staging.nylas.com"
    else
      @APIRoot = "https://invite.nylas.com"

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
        statusCode = response?.statusCode

        Actions.didMakeAPIRequest({
          request: options,
          statusCode: statusCode,
          error: error,
          requestId: requestId
        })

        if error? or statusCode > 299
          if not statusCode or statusCode in [-123, 500]
            body = "Sorry, we could not reach the Nylas API. Please try
                   again, or email us if you continue to have trouble.
                   (#{statusCode})"
          options.error(new APIError({error:error, response:response, body:body, requestOptions: options}))
        else
          options.success(body) if options.success

  _defaultErrorCallback: (apiError) ->
    console.error(apiError)

module.exports = new TokenAuthAPI
