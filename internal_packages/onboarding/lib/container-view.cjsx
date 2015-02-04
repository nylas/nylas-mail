React = require 'react/addons'
ReactCSSTransitionGroup = React.addons.CSSTransitionGroup
OnboardingActions = require './onboarding-actions'
OnboardingStore = require './onboarding-store'
querystring = require 'querystring'
{EdgehillAPI} = require 'inbox-exports'

module.exports =
ContainerView = React.createClass

  getInitialState: ->
    @getStateFromStore()

  getStateFromStore: ->
    page: OnboardingStore.page()
    error: OnboardingStore.error()
    environment: OnboardingStore.environment()
    connectType: OnboardingStore.connectType()

  componentDidMount: ->
    @unsubscribe = OnboardingStore.listen(@_onStateChanged, @)

  # It's important that every React class explicitly stops listening to
  # atom events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: ->
    @unsubscribe() if @unsubscribe

  componentDidUpdate: ->
    webview = this.refs['connect-iframe']
    if webview
      node = webview.getDOMNode()
      node.addEventListener 'did-finish-load', (e) ->
        if node.getUrl().indexOf('/connect/complete') != -1
          query = node.getUrl().split('?')[1]
          token = querystring.decode(query)
          OnboardingActions.finishedConnect(token)

  render: ->
    <div className={@state.page}>
      <ReactCSSTransitionGroup transitionName="page">
      {@_pageComponent()}
      </ReactCSSTransitionGroup>
      <div className="quit" onClick={@_fireQuit}><i className="fa fa-times"></i></div>
      <button className="btn btn-default dismiss" onClick={@_fireDismiss}>Cancel</button>
      <button className="btn btn-default back" onClick={@_fireMoveToPrevPage}>Back</button>
    </div>

  _pageComponent: ->
    if @state.error
      alert = <div className="alert alert-danger" role="alert">{@state.error}</div>
    else
      alert = <div></div>

    if @state.page is 'welcome'
      <div className="page" key={@state.page}>
        <h2>Welcome to Edgehill</h2>
        <div className="thin-container">
          <button className="btn btn-primary btn-lg btn-block" onClick={=> @_fireMoveToPage('create-account')}>Create an Account</button>
          <button className="btn btn-primary btn-lg btn-block" onClick={=> @_fireMoveToPage('sign-in')}>Sign In</button>
          <div className="environment-selector">
            <h5>Environment</h5>
            <select value={@state.environment} onChange={@_fireSetEnvironment}>
              <option value="development">Development (edgehill-dev, api-staging)</option>
              <option value="staging">Staging (edgehill-staging, api-staging)</option>
              <option value="production">Production (edgehill, api)</option>
            </select>
          </div>
        </div>
      </div>
    else if @state.page is 'sign-in'
      <div className="page" key={@state.page}>
        <form role="form" className="thin-container native-key-bindings">
          {alert}
          <div className="form-group">
            <input type="email" placeholder="Username" className="form-control" tabIndex="1" value={@state.username} onChange={@_onValueChange} id="username" />
          </div>
          <div className="form-group">
            <input type="password" placeholder="Password" className="form-control" tabIndex="2" value={@state.password} onChange={@_onValueChange} id="password" />
          </div>
          <button className="btn btn-primary btn-lg btn-block" onClick={@_fireSignIn}>Sign In</button>
        </form>
      </div>
    else if @state.page == 'create-account'
      <div className="page" key={@state.page}>
        <form role="form" className="thin-container native-key-bindings">
          {alert}
          <div className="form-group">
            <input type="text" placeholder="First Name" className="form-control" tabIndex="1" value={@state.first_name} onChange={@_onValueChange} id="first_name" />
          </div>
          <div className="form-group">
            <input type="text" placeholder="Last Name" className="form-control" tabIndex="2" value={@state.last_name} onChange={@_onValueChange} id="last_name" />
          </div>
          <div className="form-group">
            <input type="text" placeholder="Email Address" className="form-control" tabIndex="3" value={@state.email} onChange={@_onValueChange} id="email" />
          </div>
          <div className="form-group">
            <input type="email" placeholder="Username" className="form-control" tabIndex="4" value={@state.username} onChange={@_onValueChange} id="username" />
          </div>
          <div className="form-group">
            <input type="password" placeholder="Password" className="form-control" tabIndex="5" value={@state.password} onChange={@_onValueChange} id="password" />
          </div>
          <button className="btn btn-primary btn-lg btn-block" onClick={@_fireCreateAccount}>Create Account</button>
        </form>
      </div>
    else if @state.page == 'add-account'
      <div className="page" key={@state.page}>
        <h2>Connect an Account</h2>
        <p>Link accounts from other services to supercharge your email.</p>
        <div className="thin-container">
          <button className="btn btn-primary btn-lg btn-block" onClick={=> @_fireAuthAccount('salesforce')}>Salesforce</button>
          <button className="btn btn-primary btn-lg btn-block" onClick={=> @_fireAuthAccount('linkedin')}>LinkedIn</button>
        </div>
      </div>

    else if @state.page == 'add-account-auth'
      React.createElement('webview',{
        "ref": "connect-iframe",
        "key": this.state.page,
        "className": "native-key-bindings",
        "src": this._connectWebViewURL()
      });

    else if @state.page == 'add-account-success'
      # http://codepen.io/stevenfabre/pen/NPWeVb
      <div className="page" key={@state.page}>
        <div className="check">
          <svg preserveAspectRatio="xMidYMid" width="61" height="52" viewBox="0 0 61 52" className="check-icon">
            <path d="M56.560,-0.010 C37.498,10.892 26.831,26.198 20.617,33.101 C20.617,33.101 5.398,23.373 5.398,23.373 C5.398,23.373 0.010,29.051 0.010,29.051 C0.010,29.051 24.973,51.981 24.973,51.981 C29.501,41.166 42.502,21.583 60.003,6.565 C60.003,6.565 56.560,-0.010 56.560,-0.010 Z" id="path-1" class="cls-2" fill-rule="evenodd"/>
          </svg>
        </div>
      </div>


  _connectWebViewURL: ->
    EdgehillAPI.urlForConnecting(@state.connectType, @state.email)

  _onStateChanged: ->
    @setState(@getStateFromStore())

  _onValueChange: (event) ->
    changes = {}
    changes[event.target.id] = event.target.value
    @setState(changes)

  _fireDismiss: ->
    atom.close()

  _fireQuit: ->
    require('remote').require('app').quit()

  _fireSetEnvironment: (event) ->
    OnboardingActions.setEnvironment(event.target.value)

  _fireAuthAccount: (service) ->
    OnboardingActions.startConnect(service)

  _fireMoveToPage: (page) ->
    OnboardingActions.moveToPage(page)

  _fireMoveToPrevPage: ->
    OnboardingActions.moveToPreviousPage()

  _fireSignIn: (e) ->
    e.preventDefault()
    OnboardingActions.signIn(@state)

  _fireCreateAccount: (e) ->
    e.preventDefault()
    OnboardingActions.createAccount(@state)
