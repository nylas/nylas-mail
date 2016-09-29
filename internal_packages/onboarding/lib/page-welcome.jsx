import React from 'react';
import {AccountStore} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';
import OnboardingActions from './onboarding-actions';

export default class WelcomePage extends React.Component {
  static displayName = "WelcomePage";

  _onContinue = () => {
    // We don't have a NylasId yet and therefore can't track the "Welcome
    // Page Finished" event.
    //
    // If a user already has a Nylas ID and gets to this page (which
    // happens if they sign out of all of their accounts), then it would
    // properly fire. This is a rare case though and we don't want
    // analytics users thinking it's part of the full funnel.
    //
    // Actions.recordUserEvent('Welcome Page Finished');
    OnboardingActions.moveToPage("tutorial");
  }

  _onSelfHosting = () => {
    OnboardingActions.moveToPage("self-hosting-restrictions")
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
        <p className="hero-text" style={{fontSize: 20, maxWidth: 550, margin: 'auto', lineHeight: 1.7, marginTop: 30}}>Since you've been gone, we've <a href="https://nylas.com/blog/nylas-pro/">launched Nylas Pro</a>, which now requires a paid subscription. Create a Nylas ID to start your trial and continue using N1!</p>
        <RetinaImg className="icons" url="nylas://onboarding/assets/icons-bg@2x.png" mode={RetinaImg.Mode.ContentPreserve} />
      </div>
    )
  }

  render() {
    const isFirstAccount = (AccountStore.accounts().length === 0)
    return (
      <div className={`page welcome is-first-account-${isFirstAccount}`}>
        <div className="steps-container">
          {this._renderContent(isFirstAccount)}
        </div>
        <div className="footer">
          <button key="next" className="btn btn-large btn-continue" onClick={this._onContinue}>Get Started</button>
          <div className="btn-self-hosting" onClick={this._onSelfHosting}>Hosting your own sync engine?</div>
        </div>
      </div>
    );
  }
}
