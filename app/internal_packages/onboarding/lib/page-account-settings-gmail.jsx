import React from 'react';
import PropTypes from 'prop-types';

import {
  makeGmailOAuthRequest,
  buildGmailAccountFromToken,
  buildGmailSessionKey,
  buildGmailAuthURL,
} from './onboarding-helpers';

import OAuthSignInPage from './oauth-signin-page';
import OnboardingActions from './onboarding-actions';
import AccountProviders from './account-providers';

export default class AccountSettingsPageGmail extends React.Component {
  static displayName = 'AccountSettingsPageGmail';

  static propTypes = {
    account: PropTypes.object,
  };

  constructor() {
    super();
    this._sessionKey = buildGmailSessionKey();
    this._gmailAuthUrl = buildGmailAuthURL(this._sessionKey);
  }

  onSuccess(account) {
    OnboardingActions.finishAndAddAccount(account);
  }

  render() {
    const providerConfig = AccountProviders.find(a => a.provider === this.props.account.provider);
    const { headerIcon } = providerConfig;
    const goBack = () => OnboardingActions.moveToPreviousPage();

    return (
      <OAuthSignInPage
        serviceName="Google"
        providerAuthPageUrl={this._gmailAuthUrl}
        iconName={headerIcon}
        tokenRequestPollFn={makeGmailOAuthRequest}
        accountFromTokenFn={buildGmailAccountFromToken}
        onSuccess={this.onSuccess}
        onTryAgain={goBack}
        sessionKey={this._sessionKey}
      />
    );
  }
}
