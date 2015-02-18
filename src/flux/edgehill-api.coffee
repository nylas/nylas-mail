nodeRequest = require 'request'
Actions = require './actions'
{APIError} = require './errors'
DatabaseStore = require './stores/database-store'
{modelFromJSON} = require './models/utils'
async = require 'async'

class EdgehillAPI

  constructor: ->
    atom.config.onDidChange('inbox.env', @_onConfigChanged)
    @_onConfigChanged()
    @

  _onConfigChanged: =>
    env = atom.config.get('inbox.env')
    if env is 'development'
      @APIRoot = "https://edgehill-dev.nilas.com"
    else if env is 'staging'
      @APIRoot = "https://edgehill-staging.nilas.com"
    else
      @APIRoot = "https://edgehill.nilas.com"

  request: (options={}) ->
    return if atom.getLoadSettings().isSpec
    options.method ?= 'GET'
    options.url ?= "#{@APIRoot}#{options.path}" if options.path
    options.body ?= {} unless options.formData
    options.json = true

    auth = @getCredentials()
    if auth
      options.auth =
        user: auth.username
        pass: auth.password
        sendImmediately: true

    options.error ?= @_defaultErrorCallback

    nodeRequest options, (error, response, body) ->
      Actions.didMakeAPIRequest({request: options, response: response})
      if error? or response.statusCode > 299
        options.error(new APIError({error:error, response:response, body:body, requestOptions: options}))
      else
        options.success(body) if options.success

  createAccount: ({first_name, last_name, username, password}, callback) ->
    new Promise (resolve, reject) =>
      @request
        path: '/users'
        method: 'POST'
        body:
          first_name: first_name
          last_name: last_name
          username: username
          password: password
        success: =>
          @setCredentials
            username: username
            password: password
          resolve()
        error: (err) ->
          reject(err.message)

  signIn: ({username, password}) ->
    @setCredentials
      username: username
      password: password
    new Promise (resolve, reject) =>
      @request
        path: '/users/me'
        method: 'GET'
        success: (userJson) =>
          @addTokens(userJson.tokens)
          resolve(userJson)
        error: (err) =>
          @setCredentials(null)
          reject(err.message)

  urlForConnecting: (provider, email_address = '') ->
    auth = @getCredentials()
    root = @APIRoot.replace('://', "://#{auth.username}:#{auth.password}@")
    "#{root}/connect/#{provider}?login_hint=#{email_address}"

  getCredentials: ->
    atom.config.get('inbox.account')

  setCredentials: (credentials) ->
    atom.config.set('inbox.account', credentials)

  addTokens: (tokens) ->
    for token in tokens
      if token.provider is 'inbox'
        atom.config.set('inbox.token', token.access_token)
      if token.provider is 'salesforce'
        atom.config.set('salesforce.token', token.access_token)
  
  tokenForProvider: (provider) ->
    atom.config.get("#{provider}.token")

  _defaultErrorCallback: (apiError) ->
    apiError.notifyConsole()

module.exports = new EdgehillAPI
