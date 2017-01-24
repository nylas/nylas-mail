import React, {Component, PropTypes} from 'react';
import {RetinaImg} from 'nylas-component-kit';
import AccountTypes from './account-types'


class AccountOnboardingSuccess extends Component { // eslint-disable-line
  static displayName = 'AccountOnboardingSuccess'

  static propTypes = {
    accountInfo: PropTypes.object,
  }

  render() {
    const {accountInfo} = this.props
    const accountType = AccountTypes.find(a => a.type === accountInfo.type);
    return (
      <div className={`page account-setup AccountOnboardingSuccess`}>
        <div className="logo-container">
          <RetinaImg
            style={{backgroundColor: accountType.color, borderRadius: 44}}
            name={accountType.headerIcon}
            mode={RetinaImg.Mode.ContentPreserve}
            className="logo"
          />
        </div>
        <div>
          <h2>Successfully connected to {accountType.displayName}!</h2>
          <h3>Adding your account to Nylas Mail…</h3>
        </div>
      </div>
    )
  }
}

export default AccountOnboardingSuccess
