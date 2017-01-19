import React from 'react';
import {OAuthSignInPage} from 'nylas-component-kit';

import {
  tokenRequestPollForGmail,
  authIMAPForGmail,
  buildGmailSessionKey,
  buildGmailAuthURL,
} from './onboarding-helpers';

import OnboardingActions from './onboarding-actions';
import AccountTypes from './account-types';


export default class AccountSettingsPageGmail extends React.Component {
  static displayName = "AccountSettingsPageGmail";

  static propTypes = {
    accountInfo: React.PropTypes.object,
  };

  constructor() {
    super()
    this._sessionKey = buildGmailSessionKey();
    this._gmailAuthUrl = buildGmailAuthURL(this._sessionKey)
  }

  onSuccess(account) {
    OnboardingActions.accountJSONReceived(account, account.localToken, account.cloudToken);
  }

  render() {
    const {accountInfo} = this.props;
    const iconName = AccountTypes.find(a => a.type === accountInfo.type).headerIcon;
    const goBack = () => OnboardingActions.moveToPreviousPage()

    return (
      <OAuthSignInPage
        providerAuthPageUrl={this._gmailAuthUrl}
        iconName={iconName}
        tokenRequestPollFn={tokenRequestPollForGmail}
        accountFromTokenFn={authIMAPForGmail}
        onSuccess={this.onSuccess}
        onTryAgain={goBack}
        serviceName="Google"
        sessionKey={this._sessionKey}
      />
    );
  }
}
