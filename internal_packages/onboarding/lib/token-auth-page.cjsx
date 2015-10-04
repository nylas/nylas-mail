React = require 'react'
_ = require 'underscore'
{RetinaImg, TimeoutTransitionGroup} = require 'nylas-component-kit'
{Utils} = require 'nylas-exports'

TokenAuthAPI = require './token-auth-api'
OnboardingActions = require './onboarding-actions'
PageRouterStore = require './page-router-store'
Providers = require './account-types'
url = require 'url'

class TokenAuthPage extends React.Component
  @displayName: "TokenAuthPage"

  constructor: (@props) ->
    @state =
      token: ""
      tokenValidityError: null

      tokenAuthInflight: false
      tokenAuthEnabled: PageRouterStore.tokenAuthEnabled()
      tokenAuthEnabledError: PageRouterStore.tokenAuthEnabledError()

  componentDidMount: ->
    @_usub = PageRouterStore.listen(@_onTokenAuthChange)

  _onTokenAuthChange: =>
    @setState({
      tokenAuthEnabled: PageRouterStore.tokenAuthEnabled()
      tokenAuthEnabledError: PageRouterStore.tokenAuthEnabledError()
    })

  componentWillUnmount: ->
    @_usub?()

  render: =>
    if @state.tokenAuthEnabled is "unknown"
      <div className="page token-auth">
        <TimeoutTransitionGroup leaveTimeout={125} enterTimeout={125} transitionName="alpha-fade">
          {@_renderWaitingForTokenAuthAnswer()}
        </TimeoutTransitionGroup>
      </div>

    else if @state.tokenAuthEnabled is "yes"
      <div className="page token-auth token-auth-enabled">
        <div className="quit" onClick={ -> OnboardingActions.closeWindow() }>
          <RetinaImg name="onboarding-close.png" mode={RetinaImg.Mode.ContentPreserve}/>
        </div>

        <RetinaImg url="nylas://onboarding/assets/nylas-pictograph@2x.png" mode={RetinaImg.Mode.ContentIsMask} style={zoom: 0.29} className="logo"/>
        <div className="caption" style={padding: 40}>
          Due to overwhelming interest, you need an invitation code to connect
          an account to N1. Enter your invitation code below, or <a href="https://invite.nylas.com">request one here</a>.
        </div>
        {@_renderContinueError()}
        <label className="token-label">
          {@_renderInput()}
        </label>
        {@_renderContinueButton()}
      </div>
    else
      <div className="page token-auth">
      </div>

  _renderWaitingForTokenAuthAnswer: =>
    if @state.tokenAuthEnabledError
      <div style={position:'absolute', width:'100%', padding:60, paddingTop:100} key="error">
        <div className="errormsg">{@state.tokenAuthEnabledError}</div>
        <button key="retry"
                style={marginTop: 15}
                className="btn btn-large btn-retry"
                onClick={OnboardingActions.retryCheckTokenAuthStatus}>
          Try Again
        </button>
      </div>
    else
      <div style={position:'absolute', width:'100%'} key="spinner">
        <RetinaImg url="nylas://onboarding/assets/installing-spinner.gif"
                   mode={RetinaImg.Mode.ContentPreserve}
                   style={marginTop: 150}/>
      </div>

  _renderInput: =>
    if @state.errorMessage
      <input type="text"
         value={@state.token}
         onChange={@_onTokenChange}
         placeholder="Invitation Code"
         className="token-input error" />
    else
      <input type="text"
         value={@state.token}
         onChange={@_onTokenChange}
         placeholder="Invitation Code"
         className="token-input" />

  _renderContinueButton: =>
    if @state.tokenAuthInflight
      <button className="btn btn-large btn-disabled" type="button">
        <RetinaImg name="sending-spinner.gif" width={15} height={15} mode={RetinaImg.Mode.ContentPreserve} /> Checking&hellip;
      </button>
    else
      <button className="btn btn-large btn-gradient" type="button" onClick={@_onContinue}>Continue</button>

  _renderContinueError: =>
    if @state.tokenValidityError
      <div className="errormsg" role="alert">
        {@state.tokenValidityError}
      </div>
    else
      <div></div>

  _onTokenChange: (event) =>
    @setState(token: event.target.value)

  _onContinue: =>
    if not @state.token
      @setState({
        tokenAuthInflight: false,
        tokenValidityError: "Please enter an invitation code."
      })
      @_resize()
      return

    @setState({tokenAuthInflight: true, tokenValidityError: null})
    @_resize()

    TokenAuthAPI.request
      path: "/token/#{@state.token}"
      returnsModel: false
      timeout: 30000
      success: (json) =>
        atom.config.set("edgehill.token", @state.token)
        OnboardingActions.moveToPage("account-choose")
      error: (err) =>
        @setState
          tokenValidityError: err.message
          tokenAuthInflight: false
        @_resize()

  _resize: =>
    setTimeout( =>
      @props.onResize?()
    ,10)

module.exports = TokenAuthPage
