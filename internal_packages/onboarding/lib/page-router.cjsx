React = require 'react/addons'
OnboardingActions = require './onboarding-actions'
ReactCSSTransitionGroup = React.addons.CSSTransitionGroup
PageRouterStore = require './page-router-store'

WelcomePage = require './welcome-page'
AccountChoosePage = require './account-choose-page'
AccountSettingsPage = require './account-settings-page'
InitialPreferencesPage = require './initial-preferences-page'
InitialPackagesPage = require './initial-packages-page'
TokenAuthPage = require './token-auth-page'


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
    setTimeout(@_initializeWindowSize, 10)

  componentDidUpdate: =>
    setTimeout(@_updateWindowSize, 10)

  _initializeWindowSize: =>
    return if @_unmounted
    {width, height} = React.findDOMNode(@refs.activePage).getBoundingClientRect()
    atom.setSize(width, height)
    atom.center()
    atom.show()

  _updateWindowSize: =>
    return if @_unmounted
    {width, height} = React.findDOMNode(@refs.activePage).getBoundingClientRect()
    atom.setSizeAnimated(width, height)

  _onStateChanged: =>
    @setState(@_getStateFromStore())

  componentWillUnmount: =>
    @_unmounted = true
    @unsubscribe?()

  render: =>
    <div className="page-frame">
      {@_renderDragRegion()}
      <ReactCSSTransitionGroup
        transitionName="alpha-fade"
        leaveTimeout={150}
        enterTimeout={150}>
        {@_renderCurrentPage()}
        {@_renderCurrentPageGradient()}
      </ReactCSSTransitionGroup>
      <div className="page-background" style={background: "#f6f7f8"}/>
    </div>

  _renderCurrentPageGradient: =>
    gradient = @state.pageData?.provider?.color
    if gradient
      background = "linear-gradient(to top, #f6f7f8, #{gradient})"
      height = 200
    else
      background = "linear-gradient(to top, #f6f7f8 0%,  rgba(255,255,255,0) 100%), linear-gradient(to right, #e1e58f 0%, #a8d29e 50%, #8bc9c9 100%)"
      height = 330
    <div className="page-gradient" key={"#{@state.page}-gradient"} style={background: background, height: height}/>

  _renderCurrentPage: =>
    Component = {
      "welcome": WelcomePage
      "token-auth": TokenAuthPage
      "account-choose": AccountChoosePage
      "account-settings": AccountSettingsPage
      "initial-preferences": InitialPreferencesPage
      "initial-packages": InitialPackagesPage
    }[@state.page]

    <div key={@state.page} className="page-container">
      <Component pageData={@state.pageData} ref="activePage" onResize={@_updateWindowSize}/>
    </div>

  _renderDragRegion: ->
    styles =
      top:0
      left: 26
      right:0
      height: 27
      zIndex:100
      position: 'absolute'
      "WebkitAppRegion": "drag"
    <div className="dragRegion" style={styles}></div>

module.exports = PageRouter
