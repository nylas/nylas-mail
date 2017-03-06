import React from 'react';
import {IdentityStore} from 'nylas-exports';
import {Webview} from 'nylas-component-kit';
import OnboardingActions from './onboarding-actions';

export default class AuthenticatePage extends React.Component {
  static displayName = "AuthenticatePage";

  static propTypes = {
    accountInfo: React.PropTypes.object,
  };

  _src() {
    const n1Version = NylasEnv.getVersion();
    return `${IdentityStore.URLRoot}/onboarding?utm_medium=N1&utm_source=OnboardingPage&N1_version=${n1Version}&client_edition=basic`
  }

  _onDidFinishLoad = (webview) => {
    const receiveUserInfo = `
      var a = document.querySelector('#pro-account');
      result = a ? a.innerText : null;
    `;
    webview.executeJavaScript(receiveUserInfo, false, (result) => {
      this.setState({ready: true, webviewLoading: false});
      if (result !== null) {
        OnboardingActions.authenticationJSONReceived(JSON.parse(result));
      }
    });

    const openExternalLink = `
      var el = document.querySelector('.open-external');
      if (el) {el.addEventListener('click', function(event) {console.log(this.href); event.preventDefault(); return false;})}
    `;
    webview.executeJavaScript(openExternalLink);
  }

  render() {
    return (
      <div className="page authenticate">
        <Webview src={this._src()} onDidFinishLoad={this._onDidFinishLoad} />
      </div>
    );
  }
}
