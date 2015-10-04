React = require 'react'
_ = require 'underscore'
{RetinaImg} = require 'nylas-component-kit'
{Utils, SignupAPI} = require 'nylas-exports'

OnboardingActions = require './onboarding-actions'
NylasApiEnvironmentStore = require './nylas-api-environment-store'
PageRouterStore = require './page-router-store'
Providers = require './account-types'
url = require 'url'

class TokenAuthPage extends React.Component
  @displayName: "TokenAuthPage"

  constructor: (@props) ->
    @state =
      token: ""
      authError: false
      environment: NylasApiEnvironmentStore.getEnvironment()
      tokenAuthEnabled: PageRouterStore.tokenAuthEnabled()

  componentDidMount: ->
    @_usubs = []
    @_usubs.push NylasApiEnvironmentStore.listen @_onEnvironmentChange
    @_usubs.push PageRouterStore.listen @_onTokenAuthChange

  _onEnvironmentChange: =>
    @setState environment: NylasApiEnvironmentStore.getEnvironment()

  _onTokenAuthChange: =>
    @setState tokenAuthEnabled: PageRouterStore.tokenAuthEnabled()

  componentWillUnmount: ->
    usub() for usub in @_usubs

  render: =>
    if @state.authError
      <div className="page token-auth">
        <button key="retry" className="btn btn-large btn-retry" onClick={OnboardingActions.retryCheckTokenAuthStatus()}>Retry</button>
      </div>
    if @state.tokenAuthEnabled is "yes"
      <div className="page token-auth">
        <div className="quit" onClick={ -> OnboardingActions.closeWindow() }>
          <RetinaImg name="onboarding-close.png" mode={RetinaImg.Mode.ContentPreserve}/>
        </div>

        <RetinaImg url="nylas://onboarding/assets/nylas-pictograph@2x.png" mode={RetinaImg.Mode.ContentIsMask} style={zoom: 0.29} className="logo"/>
        <div className="env-select">{@_environmentComponent()}</div>
        <div className="caption" style={marginTop: 15, marginBottom:25}>Enter your invite token</div>
        {@_renderError()}
        <label className="token-label">
          {@_renderInput()}
        </label>

        <button key="next" className="btn btn-large btn-continue" onClick={@_onContinue}>Continue</button>

      </div>
    else
      <div className="page token-auth">
        <RetinaImg name="sending-spinner.gif" mode={RetinaImg.Mode.ContentPreserve} style={zoom: 0.29} className="spinner"/>
      </div>

  _renderInput: ->
    if @state.errorMessage
      <input type="text"
         value={@state.token}
         onChange={@_onTokenChange}
         className="token-input error" />
    else
      <input type="text"
         value={@state.token}
         onChange={@_onTokenChange}
         className="token-input" />

  _renderError: ->
    if @state.errorMessage
      <div className="alert alert-danger" role="alert">
        {@state.errorMessage}
      </div>
    else <div></div>

  _onTokenChange: (event) =>
    @setState token: event.target.value

  _onContinue: () =>
    SignupAPI.request
      path: "/token/#{@state.token}"
      returnsModel: false
      timeout: 30000
      success: (json) =>
        atom.config.set("edgehill.token", @state.token)
        if @state.step < 3
          @setState(step: @state.step + 1)
        else
          OnboardingActions.moveToPage("account-choose")
        return
      error: (err) => 
        @_onContinueError(err)

  _environmentComponent: =>
    return <div></div> unless atom.inDevMode()
    <div className="environment-selector">
      <select value={@state.environment} onChange={@_onEnvChange}>
        <option value="development">Development (edgehill-dev, api-staging)</option>
        <option value="experimental">Experimental (edgehill-experimental, api-experimental)</option>
        <option value="staging">Staging (edgehill-staging, api-staging)</option>
        <option value="production">Production (edgehill, api)</option>
      </select>
    </div>

  _onEnvChange: (event) =>
    OnboardingActions.changeAPIEnvironment(event.target.value)

  
  _onContinueError: (err) =>
    errorMessage = err.message
    if err.statusCode is -123 # timeout
      errorMessage = "Request timed out. Please try again."

    @setState
      errorMessage: errorMessage
      tryingToAuthenticate: false
    @_resize()

  _resize: =>
    setTimeout( =>
      @props.onResize?()
    ,10)

  _stateForMissingFieldNames: (fieldNames) ->
    fieldLabels = []
    fields = [].concat(@state.provider.settings, @state.provider.fields)

    for fieldName in fieldNames
      for s in fields when s.name is fieldName
        fieldLabels.push(s.label.toLowerCase())

    errorMessage = @_messageForFieldLabels(fieldLabels)

    {errorMessage}

module.exports = TokenAuthPage
