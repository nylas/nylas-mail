import React from 'react'
import OnboardingActions from './onboarding-actions'


class SelfHostingSetupPage extends React.Component {
  static displayName = 'SelfHostingSetupPage'

  _onContinue = () => {
    OnboardingActions.moveToPage("self-hosting-config");
  }

  render() {
    return (
      <div className="page self-hosting">
        <h2>Create your sync engine instance</h2>
        <div className="self-hosting-container">
          <div className="message empty">
            N1 needs to fetch mail from a running instance of the <a href="https://github.com/nylas/sync-engine">Nylas Sync Engine</a>. By default, N1 points to our hosted version, but the code is open source so that you can run your own instance. Note that Exchange accounts are not supported and some plugins that rely on our back-end (snoozing, open/link tracking, etc.) will not work.
          </div>
          <div className="section">
            1. Install the Nylas Sync Engine in a Vagrant virtual machine by following the <a href="https://github.com/nylas/sync-engine#installation-and-setup">installation and setup</a> instructions.
          </div>
          <div className="section">
            2. Add accounts by running the <code>inbox-auth</code> script. For example: <code>bin/inbox-auth you@gmail.com</code>.
          </div>
          <div className="section">
            3. Start the sync engine by running <code>bin/inbox-start</code> and the API via <code>bin/inbox-api</code>.
          </div>
        </div>
        <button
          key="next"
          className="btn btn-large btn-gradient"
          onClick={this._onContinue}
        >
          Done
        </button>
      </div>
    )
  }
}

export default SelfHostingSetupPage
