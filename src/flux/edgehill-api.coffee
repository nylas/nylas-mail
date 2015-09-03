_ = require 'underscore'
nodeRequest = require 'request'
Utils = require './models/utils'
Actions = require './actions'
{APIError} = require './errors'
DatabaseStore = require './stores/database-store'
PriorityUICoordinator = require '../priority-ui-coordinator'
async = require 'async'

class EdgehillAPI

  constructor: ->
    atom.config.onDidChange('env', @_onConfigChanged)
    @_onConfigChanged()

    # Always ask Edgehill Server for our tokens at launch. This way accounts
    # added elsewhere will appear, and we'll also handle the 0.2.5=>0.3.0 upgrade.
    if atom.isWorkWindow()
      existing = @_getCredentials()
      if existing and existing.username
        @setUserIdentifierAndRetrieveTokens(existing.username)

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
      Actions.willMakeAPIRequest({request: options, requestId: requestId})
      nodeRequest options, (error, response, body) ->
        Actions.didMakeAPIRequest({request: options, response: response, error: error, requestId: requestId})
        PriorityUICoordinator.settle.then ->
          if error? or response.statusCode > 299
            options.error(new APIError({error:error, response:response, body:body, requestOptions: options}))
          else
            options.success(body) if options.success

  urlForConnecting: (provider, email_address = '') ->
    auth = @_getCredentials()
    root = @APIRoot
    token = auth?.username
    "#{root}/connect/#{provider}?login_hint=#{email_address}&token=#{token}"

  setUserIdentifierAndRetrieveTokens: (user_identifier) ->
    @_setCredentials(username: user_identifier, password: '')
    @request
      path: "/users/me"
      success: (userData={}) =>
        @setTokens(userData.tokens)
        if atom.getWindowType() is 'onboarding'
          ipc = require 'ipc'
          ipc.send('login-successful')
      error: (apiError) =>
        console.error apiError

  setTokens: (incoming) ->
    # todo: remove once the edgehill-server inbox service is called `nylas`
    for token in incoming
      if token.provider is 'inbox'
        token.provider = 'nylas'
    atom.config.set('tokens', incoming)
    atom.config.save()

  unlinkToken: (token) ->
    @request
      path: "/users/token/#{token.id}"
      method: 'DELETE'
      success: =>
        tokens = atom.config.get('tokens') || []
        tokens = _.reject tokens, (t) -> t.id is token.id
        atom.config.set('tokens', tokens)

  accessTokenForProvider: (provider) ->
    tokens = atom.config.get('tokens') || []
    for token in tokens
      if token.provider is provider
        return token.access_token
    return null

  _getCredentials: ->
    atom.config.get('edgehill.credentials')

  _setCredentials: (credentials) ->
    atom.config.set('edgehill.credentials', credentials)

  _defaultErrorCallback: (apiError) ->
    console.error(apiError)

module.exports = new EdgehillAPI
