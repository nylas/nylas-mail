import React from 'react'
import {RetinaImg} from 'nylas-component-kit'
import OnboardingActions from './onboarding-actions'

export default class SelfHostingRestrictionsPage extends React.Component {
  static displayName = 'SelfHostingRestrictionsPage'

  _onContinue = () => {
    OnboardingActions.moveToPage("self-hosting-setup");
  }

  render() {
    return (
      <div className="page self-hosting">
        <h2>Are you sure?</h2>
        <div className="self-hosting-container">
          <div className="section">
            Some of N1&#39;s most powerful features, like snooze, read receipts, and
            send later, require the hosted version of our backend infrastructure.
            These features won&#39;t be available while you use N1 with your own sync
            engine.
          </div>
          <div className="section">
            <RetinaImg
              name="pro-plugins.png"
              mode={RetinaImg.Mode.ContentPreserve}
            />
          </div>
        </div>
        <button
          key="next"
          className="btn btn-large btn-gradient"
          onClick={this._onContinue}
        >
          Continue without Nylas Pro features
        </button>
      </div>
    )
  }
}
