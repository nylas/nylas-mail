React = require 'react'
Page = require './page'
{RetinaImg} = require 'nylas-component-kit'
{EdgehillAPI} = require 'nylas-exports'
OnboardingActions = require './onboarding-actions'

class ConnectAccountPage extends Page
  @displayName: "ConnectAccountPage"

  render: =>
    <div className="page">
      {@_renderClose("close")}

      <RetinaImg name="onboarding-logo.png" mode={RetinaImg.Mode.ContentPreserve} className="logo"/>

      <h2>Connect an Account</h2>

      <RetinaImg name="onboarding-divider.png" mode={RetinaImg.Mode.ContentPreserve} />

      <div className="thin-container">
        <div className="prompt">Link accounts from other services to supercharge your email.</div>
        <button className="btn btn-larger btn-gradient" onClick={=> @_fireAuthAccount('salesforce')}>Salesforce</button>
      </div>

    </div>

  _fireAuthAccount: (service) =>
    url = EdgehillAPI.urlForConnecting(service)
    OnboardingActions.moveToPage "add-account-auth", {url}

module.exports = ConnectAccountPage
