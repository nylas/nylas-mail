Reflux = require 'reflux'
OnboardingActions = require './onboarding-actions'
NylasStore = require 'nylas-store'
ipc = require 'ipc'

return unless atom.getWindowType() is "onboarding"

class PageRouterStore extends NylasStore
  constructor: ->
    atom.onWindowPropsReceived @_onWindowPropsChagned

    @_page = atom.getWindowProps().page ? ''
    @_pageData = atom.getWindowProps().pageData ? {}

    @_pageStack = [{page: @_page, pageData: @_pageData}]

    @listenTo OnboardingActions.moveToPreviousPage, @_onMoveToPreviousPage
    @listenTo OnboardingActions.moveToPage, @_onMoveToPage

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
