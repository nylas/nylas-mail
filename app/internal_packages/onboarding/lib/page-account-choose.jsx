import React from 'react';
import {RetinaImg} from 'nylas-component-kit';
import OnboardingActions from './onboarding-actions';
import AccountProviders from './account-providers';

export default class AccountChoosePage extends React.Component {
  static displayName = "AccountChoosePage";

  static propTypes = {
    account: React.PropTypes.object,
  }

  _renderProviders() {
    return AccountProviders.map(({icon, displayName, provider}) =>
      <div
        key={provider}
        className={`provider ${provider}`}
        onClick={() => OnboardingActions.chooseAccountProvider(provider)}
      >
        <div className="icon-container">
          <RetinaImg
            name={icon}
            mode={RetinaImg.Mode.ContentPreserve}
            className="icon"
          />
        </div>
        <span className="provider-name">{displayName}</span>
      </div>
    );
  }

  render() {
    return (
      <div className="page account-choose">
        <h2>
          Connect an email account
        </h2>
        <div className="provider-list">
          {this._renderProviders()}
        </div>
      </div>
    );
  }
}
