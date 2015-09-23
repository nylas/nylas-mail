React = require 'react'
_ = require 'underscore'
{RetinaImg} = require 'nylas-component-kit'
{EdgehillAPI, Utils} = require 'nylas-exports'

Page = require './page'
OnboardingActions = require './onboarding-actions'
NylasApiEnvironmentStore = require './nylas-api-environment-store'
Providers = require './account-types'
url = require 'url'

class AccountChoosePage extends Page
  @displayName: "AccountChoosePage"

  constructor: (@props) ->
    @state =
      email: ""
      provider: ""
      environment: NylasApiEnvironmentStore.getEnvironment()

  componentDidMount: ->
    @_usub = NylasApiEnvironmentStore.listen =>
      @setState environment: NylasApiEnvironmentStore.getEnvironment()

  componentWillUnmount: ->
    @_usub?()

  render: =>
    <div className="page account-choose">
      {@_renderClose("quit")}

      <div className="logo-container">
        <RetinaImg name="onboarding-logo.png" mode={RetinaImg.Mode.ContentPreserve} className="logo"/>
      </div>

      <div className="caption" style={marginBottom:20}>Select your email provider</div>

      {@_renderProviders()}

    </div>

  _renderProviders: ->
    return Providers.map (provider) =>
      <div className={"provider "+provider.name} key={provider.name} onClick={=>@_onChooseProvider(provider)}>

        <div className="icon-container">
          <RetinaImg name={provider.icon} mode={RetinaImg.Mode.ContentPreserve} className="icon"/>
        </div>
        {provider.displayName}
      </div>

  _renderError: ->
    if @state.error
      <div className="alert alert-danger" role="alert">
        {@state.error}
      </div>
    else <div></div>

  _onEmailChange: (event) =>
    @setState email: event.target.value

  _onChooseProvider: (provider) =>
    if provider.name is 'gmail'
      # Show the "Sign in to Gmail" prompt for a moment before actually bouncing
      # to Gmail. (400msec animation + 200msec to read)
      _.delay =>
        @_onBounceToGmail(provider)
      , 600
    OnboardingActions.moveToPage("account-settings", {provider})

  _onBounceToGmail: (provider) =>
    provider.clientKey = Utils.generateTempId()[6..]+'-'+Utils.generateTempId()[6..]
    shell = require 'shell'
    googleUrl = url.format({
      protocol: 'https'
      host: 'accounts.google.com/o/oauth2/auth'
      query:
        response_type: 'code'
        state: provider.clientKey
        client_id: '372024217839-cdsnrrqfr4d6b4gmlqepd7v0n0l0ip9q.apps.googleusercontent.com'
        redirect_uri: "#{EdgehillAPI.APIRoot}/oauth/google/callback"
        access_type: 'offline'
        scope: 'https://www.googleapis.com/auth/userinfo.email \
            https://www.googleapis.com/auth/userinfo.profile \
            https://mail.google.com/ \
            https://www.google.com/m8/feeds \
            https://www.googleapis.com/auth/calendar'
    })
    shell.openExternal(googleUrl)

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
        <option value="experimental">Experimental (edgehill-experimental, api-experimental)</option>
        <option value="staging">Staging (edgehill-staging, api-staging)</option>
        <option value="production">Production (edgehill, api)</option>
      </select>
    </div>

  _onEnvChange: (event) =>
    OnboardingActions.changeAPIEnvironment(event.target.value)

module.exports = AccountChoosePage
