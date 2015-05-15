Reflux = require 'reflux'
Actions = require './onboarding-actions'
{EdgehillAPI} = require 'nylas-exports'
ipc = require 'ipc'

return unless atom.getWindowType() is "onboarding"

module.exports =
OnboardingStore = Reflux.createStore
  init: ->
    @_error = ''
    @_page = atom.getLoadSettings().page || 'welcome'

    @_pageStack = [@_page]

    # For the time being, always use staging
    defaultEnv = if atom.inDevMode() then 'staging' else 'staging'
    atom.config.set('env', defaultEnv) unless atom.config.get('env')

    @listenTo Actions.setEnvironment, @_onSetEnvironment
    @listenTo Actions.moveToPreviousPage, @_onMoveToPreviousPage
    @listenTo Actions.moveToPage, @_onMoveToPage
    @listenTo Actions.startConnect, @_onStartConnect
    @listenTo Actions.finishedConnect, @_onFinishedConnect

  page: ->
    @_page

  error: ->
    @_error

  environment: ->
    atom.config.get('env')

  connectType: ->
    @_connectType

  _onMoveToPreviousPage: ->
    current = @_pageStack.pop()
    prev = @_pageStack.pop()
    @_onMoveToPage(prev)

  _onMoveToPage: (page) ->
    @_error = null
    @_pageStack.push(page)
    @_page = page
    @trigger()

  _onStartConnect: (service) ->
    @_connectType = service
    @_onMoveToPage('add-account-auth')

  _onFinishedConnect: (token) ->
    EdgehillAPI.addTokens([token])
    @_onMoveToPage('add-account-success')

    setTimeout ->
      atom.close()
    , 2500

  _onSetEnvironment: (env) ->
    throw new Error("Environment #{env} is not allowed") unless env in ['development', 'staging', 'production']
    atom.config.set('env', env)
    @trigger()
