import React, { Component } from 'react';
import PropTypes from 'prop-types';
import { RetinaImg } from 'mailspring-component-kit';
import AccountProviders from './account-providers';

class AccountOnboardingSuccess extends Component {
  // eslint-disable-line
  static displayName = 'AccountOnboardingSuccess';

  static propTypes = {
    account: PropTypes.object,
  };

  render() {
    const { account } = this.props;
    const providerConfig = AccountProviders.find(({ provider }) => provider === account.provider);

    return (
      <div className={`page account-setup AccountOnboardingSuccess`}>
        <div className="logo-container">
          <RetinaImg
            style={{ backgroundColor: providerConfig.color, borderRadius: 44 }}
            name={providerConfig.headerIcon}
            mode={RetinaImg.Mode.ContentPreserve}
            className="logo"
          />
        </div>
        <div>
          <h2>Successfully connected to {providerConfig.displayName}!</h2>
          <h3>Adding your account to Mailspring…</h3>
        </div>
      </div>
    );
  }
}

export default AccountOnboardingSuccess;
