React = require 'react/addons'
OnboardingActions = require './onboarding-actions'
ReactCSSTransitionGroup = React.addons.CSSTransitionGroup
PageRouterStore = require './page-router-store'

LoginPage = require './login-page'
ConnectAccountPage = require './connect-account-page'
ExternalAuthWebviewPage = require './external-auth-webview-page'
SuccessPage = require './success-page'

class PageRouter extends React.Component
  @displayName: 'PageRouter'
  @containerRequired: false

  constructor: (@props) ->
    @state = @_getStateFromStore()
    window.OnboardingActions = OnboardingActions

  _getStateFromStore: =>
    page: PageRouterStore.page()
    pageData: PageRouterStore.pageData()

  componentDidMount: =>
    @unsubscribe = PageRouterStore.listen(@_onStateChanged, @)

  _onStateChanged: => @setState(@_getStateFromStore())

  componentWillUnmount: => @unsubscribe?()

  render: =>
    <div className="page-frame">
      <ReactCSSTransitionGroup transitionName="page">
        {@_renderCurrentPage()}
        {@_renderDragRegion()}
      </ReactCSSTransitionGroup>
    </div>

  _renderCurrentPage: =>
    switch @state.page
      when "welcome"
        <LoginPage pageData={@state.pageData} />
      when "add-account"
        <ConnectAccountPage pageData={@state.pageData} />
      when "add-account-auth"
        <ExternalAuthWebviewPage pageData={@state.pageData} />
      when "add-account-success"
        <SuccessPage pageData={@state.pageData} />
      else
        <div></div>

  _renderDragRegion: ->
    styles =
      top:0
      left:40
      right:0
      height: 20
      zIndex:100
      position: 'absolute'
      "WebkitAppRegion": "drag"
    <div className="dragRegion" style={styles}></div>

module.exports = PageRouter
