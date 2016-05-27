import React from 'react';
import {Actions, AccountStore} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';
import OnboardingActions from './onboarding-actions';

export default class WelcomePage extends React.Component {
  static displayName = "WelcomePage";

  _onContinue = () => {
    Actions.recordUserEvent('Welcome Page Finished');
    OnboardingActions.moveToPage("tutorial");
  }

  _renderContent(isFirstAccount) {
    if (isFirstAccount) {
      return (
        <div>
          <RetinaImg className="logo" style={{marginTop: 166}} url="nylas://onboarding/assets/nylas-logo@2x.png" mode={RetinaImg.Mode.ContentPreserve} />
          <p className="hero-text" style={{fontSize: 46, marginTop: 57}}>Welcome to Nylas N1</p>
          <RetinaImg className="icons" url="nylas://onboarding/assets/icons-bg@2x.png" mode={RetinaImg.Mode.ContentPreserve} />
        </div>
      )
    }
    return (
      <div>
        <p className="hero-text" style={{fontSize: 46, marginTop: 187}}>Welcome back!</p>
        <p className="hero-text" style={{fontSize: 20, maxWidth: 550, margin: 'auto', lineHeight: 1.7, marginTop: 30}}>This month we're <a href="https://nylas.com/blog/nylas-pro/">launching Nylas Pro</a>. As an existing user, you'll receive a coupon for your first year free. Create a Nylas ID to continue using N1, and look out for a coupon email!</p>
        <RetinaImg className="icons" url="nylas://onboarding/assets/icons-bg@2x.png" mode={RetinaImg.Mode.ContentPreserve} />
      </div>
    )
  }

  render() {
    const isFirstAccount = (AccountStore.accounts().length === 0);

    return (
      <div className={`page welcome is-first-account-${isFirstAccount}`}>
        <div className="steps-container">
          {this._renderContent(isFirstAccount)}
        </div>
        <div className="footer">
          <button key="next" className="btn btn-large btn-continue" onClick={this._onContinue}>Get Started</button>
        </div>
      </div>
    );
  }
}
