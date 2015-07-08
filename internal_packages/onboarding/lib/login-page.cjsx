React = require 'react'

{RetinaImg} = require 'nylas-component-kit'
{EdgehillAPI} = require 'nylas-exports'

Page = require './page'
OnboardingActions = require './onboarding-actions'
NylasApiEnvironmentStore = require './nylas-api-environment-store'

class LoginPage extends Page
  @displayName: "LoginPage"

  constructor: (@props) ->
    @state =
      email: ""
      environment: NylasApiEnvironmentStore.getEnvironment()

  componentDidMount: ->
    @_usub = NylasApiEnvironmentStore.listen =>
      @setState environment: NylasApiEnvironmentStore.getEnvironment()

  componentWillUnmount: ->
    @_usub?()

  render: =>
    <div className="page">
      {@_renderClose("quit")}

      <RetinaImg name="onboarding-logo.png" mode={RetinaImg.Mode.ContentPreserve} className="logo"/>

      <h2>Welcome to Nylas</h2>

      <RetinaImg name="onboarding-divider.png" mode={RetinaImg.Mode.ContentPreserve} />

      <form role="form" ref="form" onSubmit={@_onSubmit} className="email-form thin-container">
        <div className="prompt">Enter your email address:</div>

        <input type="email"
               required={true}
               ref="email"
               className="input-email input-bordered"
               placeholder="you@gmail.com"
               tabIndex="1"
               value={@state.email}
               onChange={@_onEmailChange}
               id="email"
               spellCheck="false"/>

        <button className="btn btn-larger btn-gradient"
                style={width:215}>Start using Nylas</button>
        {@_environmentComponent()}
      </form>

    </div>

  _renderError: ->
    if @state.error
      <div className="alert alert-danger" role="alert">
        {@state.error}
      </div>
    else <div></div>

  _onEmailChange: (event) =>
    @setState email: event.target.value

  _onSubmit: (e) =>
    valid = React.findDOMNode(@refs.form).reportValidity()
    if valid
      url = EdgehillAPI.urlForConnecting("inbox", @state.email)
      OnboardingActions.moveToPage("add-account-auth", {url})
    else
    e.preventDefault()

  _environmentComponent: =>
    return <div></div> unless atom.inDevMode()
    <div className="environment-selector">
      <select value={@state.environment} onChange={@_onEnvChange}>
        <option value="development">Development (edgehill-dev, api-staging)</option>
        <option value="experimental">Experimental (edgehill-staging, api-experimental)</option>
        <option value="staging">Staging (edgehill-staging, api-staging)</option>
        <option value="production">Production (edgehill, api)</option>
      </select>
    </div>

  _onEnvChange: (event) =>
    OnboardingActions.changeAPIEnvironment event.target.value

module.exports = LoginPage
