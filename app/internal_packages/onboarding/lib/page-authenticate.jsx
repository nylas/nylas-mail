import { React, PropTypes, MailspringAPIRequest } from 'mailspring-exports';
import { Webview } from 'mailspring-component-kit';
import OnboardingActions from './onboarding-actions';

export default class AuthenticatePage extends React.Component {
  static displayName = 'AuthenticatePage';

  static propTypes = {
    account: PropTypes.object,
  };

  _src() {
    const n1Version = AppEnv.getVersion();
    return `${MailspringAPIRequest.rootURLForServer(
      'identity'
    )}/onboarding?utm_medium=N1&utm_source=OnboardingPage&N1_version=${n1Version}&client_edition=basic`;
  }

  _onDidFinishLoad = webview => {
    const receiveUserInfo = `
      var a = document.querySelector('#identity-result');
      result = a ? a.innerText : null;
    `;
    webview.executeJavaScript(receiveUserInfo, false, result => {
      this.setState({ ready: true, webviewLoading: false });
      if (result !== null) {
        OnboardingActions.identityJSONReceived(JSON.parse(atob(result)));
      }
    });

    const openExternalLink = `
      var el = document.querySelector('.open-external');
      if (el) {el.addEventListener('click', function(event) {console.log(this.href); event.preventDefault(); return false;})}
    `;
    webview.executeJavaScript(openExternalLink);
  };

  render() {
    return (
      <div className="page authenticate">
        <Webview src={this._src()} onDidFinishLoad={this._onDidFinishLoad} />
      </div>
    );
  }
}
