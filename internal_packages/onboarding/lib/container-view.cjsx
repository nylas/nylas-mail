React = require 'react/addons'
ReactCSSTransitionGroup = React.addons.CSSTransitionGroup
OnboardingActions = require './onboarding-actions'
OnboardingStore = require './onboarding-store'
querystring = require 'querystring'
{EdgehillAPI} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class ContainerView extends React.Component

  constructor: (@props) ->
    @state = @getStateFromStore()

  getStateFromStore: =>
    page: OnboardingStore.page()
    error: OnboardingStore.error()
    environment: OnboardingStore.environment()
    connectType: OnboardingStore.connectType()

  componentDidMount: =>
    @unsubscribe = OnboardingStore.listen(@_onStateChanged, @)

  # It's important that every React class explicitly stops listening to
  # atom events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: =>
    @unsubscribe() if @unsubscribe

  componentDidUpdate: =>
    webview = @refs['connect-iframe']
    if webview
      node = React.findDOMNode(webview)
      if node.hasListeners is undefined
        # Remove as soon as possible. Initial src is not correctly loaded
        # on webview, and this fixes it. Electron 0.26.0
        setTimeout -> node.src = node.src
        node.addEventListener 'new-window', (e) ->
          require('shell').openExternal(e.url)
        node.addEventListener 'did-start-loading', (e) ->
          if node.hasMobileUserAgent is undefined
            node.setUserAgent("Mozilla/5.0 (iPhone; CPU iPhone OS 7_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D167 Safari/9537.53")
            node.hasMobileUserAgent = true
            node.reload()
        node.addEventListener 'did-finish-load', (e) ->
          if node.getUrl().indexOf('/connect/complete') != -1
            query = node.getUrl().split('?')[1]
            query = query[0..-2] if query[query.length - 1] is '#'
            token = querystring.decode(query)
            OnboardingActions.finishedConnect(token)
          if node.getUrl().indexOf('cancelled') != -1
            OnboardingActions.moveToPreviousPage()

  render: =>
    <ReactCSSTransitionGroup transitionName="page">
    {@_pageComponent()}
    <div className="dragRegion" style={"WebkitAppRegion": "drag", position: 'absolute', top:0, left:40, right:0, height: 20, zIndex:100}></div>
    </ReactCSSTransitionGroup>

  _pageComponent: =>
    if @state.error
      alert = <div className="alert alert-danger" role="alert">{@state.error}</div>
    else
      alert = <div></div>

    if @state.page is 'welcome'
      <div className="page" key={@state.page}>
        <div className="quit" onClick={@_fireQuit}>
          <RetinaImg name="onboarding-close.png"/>
        </div>
        <RetinaImg name="onboarding-logo.png" className="logo"/>
        <h2>Welcome to Nylas</h2>

        <RetinaImg name="onboarding-divider.png" />

        <form role="form" className="thin-container">
          <div className="prompt">Enter your email address:</div>
          <input className="input-bordered"
                 type="email"
                 placeholder="you@gmail.com"
                 tabIndex="1"
                 value={@state.email}
                 onChange={@_onValueChange}
                 id="email"
                 spellCheck="false"/>
          <button className="btn btn-larger btn-gradient" style={width:215} onClick={@_fireStart}>Start using Nylas</button>
          {@_environmentComponent()}
        </form>

      </div>

    else if @state.page == 'add-account'
      <div className="page" key={@state.page}>
        <div className="quit" onClick={@_fireDismiss}>
          <RetinaImg name="onboarding-close.png"/>
        </div>
        <RetinaImg name="onboarding-logo.png" className="logo"/>
        <h2>Connect an Account</h2>

        <RetinaImg name="onboarding-divider.png" />

        <form role="form" className="thin-container">
          <div className="prompt">Link accounts from other services to supercharge your email.</div>
          <button className="btn btn-larger btn-gradient" onClick={=> @_fireAuthAccount('salesforce')}>Salesforce</button>
          <button className="btn btn-larger btn-gradient" onClick={=> @_fireAuthAccount('linkedin')}>LinkedIn</button>
        </form>
      </div>

    else if @state.page == 'add-account-auth'
      <div>
        {
          React.createElement('webview',{
            "ref": "connect-iframe",
            "key": @state.page,
            "src": @_connectWebViewURL()
          })
        }
        <div className="back" onClick={@_fireMoveToPrevPage}>
          <RetinaImg name="onboarding-back.png"/>
        </div>
      </div>

    else if @state.page == 'add-account-success'
      # http://codepen.io/stevenfabre/pen/NPWeVb
      <div className="page" key={@state.page}>
        <div className="check">
          <svg preserveAspectRatio="xMidYMid" width="61" height="52" viewBox="0 0 61 52" className="check-icon">
            <path d="M56.560,-0.010 C37.498,10.892 26.831,26.198 20.617,33.101 C20.617,33.101 5.398,23.373 5.398,23.373 C5.398,23.373 0.010,29.051 0.010,29.051 C0.010,29.051 24.973,51.981 24.973,51.981 C29.501,41.166 42.502,21.583 60.003,6.565 C60.003,6.565 56.560,-0.010 56.560,-0.010 Z" id="path-1" className="cls-2" fill-rule="evenodd"/>
          </svg>
        </div>
      </div>

  _environmentComponent: =>
    return [] unless atom.inDevMode()
    <div className="environment-selector">
      <select value={@state.environment} onChange={@_fireSetEnvironment}>
        <option value="development">Development (edgehill-dev, api-staging)</option>
        <option value="staging">Staging (edgehill-staging, api-staging)</option>
        <option value="production">Production (edgehill, api)</option>
      </select>
    </div>

  _connectWebViewURL: =>
    EdgehillAPI.urlForConnecting(@state.connectType, @state.email)

  _onStateChanged: =>
    @setState(@getStateFromStore())

  _onValueChange: (event) =>
    changes = {}
    changes[event.target.id] = event.target.value
    @setState(changes)

  _fireDismiss: =>
    atom.close()

  _fireQuit: =>
    require('ipc').send('command', 'application:quit')

  _fireSetEnvironment: (event) =>
    OnboardingActions.setEnvironment(event.target.value)

  _fireStart: (e) =>
    OnboardingActions.startConnect('inbox')

  _fireAuthAccount: (service) =>
    OnboardingActions.startConnect(service)

  _fireMoveToPage: (page) =>
    OnboardingActions.moveToPage(page)

  _fireMoveToPrevPage: =>
    OnboardingActions.moveToPreviousPage()


module.exports = ContainerView
