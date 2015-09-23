Reflux = require 'reflux'
OnboardingActions = require './onboarding-actions'
NylasStore = require 'nylas-store'
ipc = require 'ipc'
url = require 'url'

return unless atom.getWindowType() is "onboarding"

class PageRouterStore extends NylasStore
  constructor: ->
    atom.onWindowPropsReceived @_onWindowPropsChagned

    @_page = atom.getWindowProps().page ? ''
    @_pageData = atom.getWindowProps().pageData ? {}

    @_pageStack = [{page: @_page, pageData: @_pageData}]

    @listenTo OnboardingActions.moveToPreviousPage, @_onMoveToPreviousPage
    @listenTo OnboardingActions.moveToPage, @_onMoveToPage
    @listenTo OnboardingActions.nylasAccountReceived, @_onNylasAccountReceived

  _onNylasAccountReceived: (account) =>
    tokens = atom.config.get('tokens') || []
    tokens.push({
      provider: 'nylas'
      identifier: account.email_address
      access_token: account.auth_token
    })
    atom.config.set('tokens', tokens)
    atom.config.save()
    @_onMoveToPage('initial-preferences', {account})

  _onWindowPropsChagned: ({page, pageData}={}) =>
    @_onMoveToPage(page, pageData)

  page: -> @_page

  pageData: -> @_pageData

  connectType: ->
    @_connectType

  _onMoveToPreviousPage: ->
    current = @_pageStack.pop()
    prev = @_pageStack.pop()
    @_onMoveToPage(prev.page, prev.pageData)

  _onMoveToPage: (page, pageData={}) ->
    @_pageStack.push({page, pageData})
    @_page = page
    @_pageData = pageData
    @trigger()

module.exports = new PageRouterStore()
