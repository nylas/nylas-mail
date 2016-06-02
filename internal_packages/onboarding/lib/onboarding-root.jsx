import React from 'react';
import ReactCSSTransitionGroup from 'react-addons-css-transition-group';
import OnboardingStore from './onboarding-store';
import PageTopBar from './page-top-bar';

import WelcomePage from './page-welcome';
import TutorialPage from './page-tutorial';
import AuthenticatePage from './page-authenticate';
import AccountChoosePage from './page-account-choose';
import AccountSettingsPage from './page-account-settings';
import AccountSettingsPageGmail from './page-account-settings-gmail';
import AccountSettingsPageIMAP from './page-account-settings-imap';
import AccountSettingsPageExchange from './page-account-settings-exchange';
import InitialPreferencesPage from './page-initial-preferences';

const PageComponents = {
  "welcome": WelcomePage,
  "tutorial": TutorialPage,
  "authenticate": AuthenticatePage,
  "account-choose": AccountChoosePage,
  "account-settings": AccountSettingsPage,
  "account-settings-gmail": AccountSettingsPageGmail,
  "account-settings-imap": AccountSettingsPageIMAP,
  "account-settings-exchange": AccountSettingsPageExchange,
  "initial-preferences": InitialPreferencesPage,
}

export default class OnboardingRoot extends React.Component {
  static displayName = 'OnboardingRoot';
  static containerRequired = false;

  constructor(props) {
    super(props);
    this.state = this._getStateFromStore();
  }

  componentDidMount() {
    this.unsubscribe = OnboardingStore.listen(this._onStateChanged, this);
    NylasEnv.center();
    NylasEnv.displayWindow();
  }

  componentWillUnmount() {
    if (this.unsubscribe) {
      this.unsubscribe();
    }
  }

  _getStateFromStore = () => {
    return {
      page: OnboardingStore.page(),
      pageDepth: OnboardingStore.pageDepth(),
      accountInfo: OnboardingStore.accountInfo(),
    };
  }

  _onStateChanged = () => {
    this.setState(this._getStateFromStore());
  }

  render() {
    const Component = PageComponents[this.state.page];
    if (!Component) {
      throw new Error(`Cannot find component for page: ${this.state.page}`);
    }

    return (
      <div className="page-frame">
        <PageTopBar pageDepth={this.state.pageDepth} />
        <ReactCSSTransitionGroup
          transitionName="alpha-fade"
          transitionLeaveTimeout={150}
          transitionEnterTimeout={150}
        >
          <div key={this.state.page} className="page-container">
            <Component accountInfo={this.state.accountInfo} ref="activePage" />
          </div>
        </ReactCSSTransitionGroup>
      </div>
    );
  }
}
