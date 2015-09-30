Reflux = require 'reflux'
OnboardingActions = require './onboarding-actions'
{AccountStore} = require 'nylas-exports'
NylasStore = require 'nylas-store'
ipc = require 'ipc'
url = require 'url'

return unless atom.getWindowType() is "onboarding"

class PageRouterStore extends NylasStore
  constructor: ->
    atom.onWindowPropsReceived @_onWindowPropsChanged

    @_page = atom.getWindowProps().page ? ''
    @_pageData = atom.getWindowProps().pageData ? {}

    @_pageStack = [{page: @_page, pageData: @_pageData}]

    @listenTo OnboardingActions.moveToPreviousPage, @_onMoveToPreviousPage
    @listenTo OnboardingActions.moveToPage, @_onMoveToPage
    @listenTo OnboardingActions.closeWindow, @_onCloseWindow
    @listenTo OnboardingActions.accountJSONReceived, @_onAccountJSONReceived

  _onAccountJSONReceived: (json) =>
    isFirstAccount = AccountStore.items().length is 0
    AccountStore.addAccountFromJSON(json)
    ipc.send('new-account-added')
    atom.displayWindow()
    if isFirstAccount
      @_onMoveToPage('initial-preferences', {account: json})
    else
      ipc.send('account-setup-successful')

  _onWindowPropsChanged: ({page, pageData}={}) =>
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

  _onCloseWindow: ->
    isFirstAccount = AccountStore.items().length is 0
    if isFirstAccount
      atom.quit()
    else
      atom.close()

module.exports = new PageRouterStore()
