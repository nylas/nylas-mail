nodeRequest = require 'request'
Actions = require './actions'
{APIError} = require './errors'
DatabaseStore = require './stores/database-store'
PriorityUICoordinator = require '../priority-ui-coordinator'
{modelFromJSON} = require './models/utils'
async = require 'async'

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
      @APIRoot = "https://edgehill-staging.nylas.com"
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
    if auth
      options.auth =
        user: auth.username
        pass: auth.password
        sendImmediately: true

    options.error ?= @_defaultErrorCallback

    nodeRequest options, (error, response, body) ->
      PriorityUICoordinator.settle.then ->
        Actions.didMakeAPIRequest({request: options, response: response})
        if error? or response.statusCode > 299
          options.error(new APIError({error:error, response:response, body:body, requestOptions: options}))
        else
          options.success(body) if options.success

  urlForConnecting: (provider, email_address = '') ->
    auth = @_getCredentials()
    root = @APIRoot
    token = auth?.username
    "#{root}/connect/#{provider}?login_hint=#{email_address}&token=#{token}"

  addTokens: (tokens) ->
    for token in tokens
      atom.config.set("#{token.provider}.token", token.access_token)

      # todo: remove once the edgehill-server inbox service is called `nylas`
      if token.provider is 'inbox'
        atom.config.set("nylas.token", token.access_token)

      if token.user_identifier?
        @_setCredentials({username: token.user_identifier, password: ''})

  tokenForProvider: (provider) ->
    atom.config.get("#{provider}.token")

  _getCredentials: ->
    atom.config.get('edgehill.credentials')

  _setCredentials: (credentials) ->
    atom.config.set('edgehill.credentials', credentials)

  _defaultErrorCallback: (apiError) ->
    apiError.notifyConsole()

module.exports = new EdgehillAPI
