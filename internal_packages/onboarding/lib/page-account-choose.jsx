import React from 'react';
import {RetinaImg} from 'nylas-component-kit';
import OnboardingActions from './onboarding-actions';
import AccountTypes from './account-types';
import SelfHostingConfigPage from './page-self-hosting-config'

export default class AccountChoosePage extends React.Component {
  static displayName = "AccountChoosePage";

  static propTypes = {
    accountInfo: React.PropTypes.object,
  }

  _renderAccountTypes() {
    return AccountTypes.map((accountType) =>
      <div
        key={accountType.type}
        className={`provider ${accountType.type}`}
        onClick={() => OnboardingActions.setAccountType(accountType.type)}
      >
        <div className="icon-container">
          <RetinaImg
            name={accountType.icon}
            mode={RetinaImg.Mode.ContentPreserve}
            className="icon"
          />
        </div>
        <span className="provider-name">{accountType.displayName}</span>
      </div>
    );
  }

  _connectPrompt() {
    const accounts = NylasEnv.config.get("nylas.accounts") || []
    if (NylasEnv.config.get("nylasMailBasicMigrationTime") && accounts.length === 0) {
      return (
        <h2 style={{marginTop: "35px", lineHeight: "36px"}}>
          Welcome to Nylas Pro
          <br />
          <span style={{fontSize: "23px"}}>Please connect your email accounts.</span>
        </h2>
      )
    }
    return <h2>Connect an email account</h2>
  }

  render() {
    if (NylasEnv.config.get('env') === 'custom' ||
      NylasEnv.config.get('env') === 'local') {
      return (<SelfHostingConfigPage addAccount />)
    }

    return (
      <div className="page account-choose">
        {this._connectPrompt()}
        <div className="cloud-sync-note">
          <a href="https://support.nylas.com/hc/en-us/articles/217518207-Why-does-Nylas-N1-sync-email-via-the-cloud-">Learn more</a> about how Nylas Pro syncs your mail in the cloud.
        </div>
        <div className="provider-list">
          {this._renderAccountTypes()}
        </div>
      </div>
    );
  }
}
