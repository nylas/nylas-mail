import React from 'react';
import classnames from 'classnames';
import ReactDOM from 'react-dom';
import {IdentityStore} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';
import OnboardingActions from './onboarding-actions';
import networkErrors from 'chromium-net-errors';

class InitialLoadingCover extends React.Component {
  static propTypes = {
    ready: React.PropTypes.bool,
    error: React.PropTypes.string,
    onTryAgain: React.PropTypes.func,
  }

  constructor(props) {
    super(props);
    this.state = {};
  }

  componentDidMount() {
    this._slowTimeout = setTimeout(() => {
      this.setState({slow: true});
    }, 2500);
  }

  componentWillUnmount() {
    clearTimeout(this._slowTimeout);
    this._slowTimeout = null;
  }

  render() {
    const classes = classnames({
      'webview-cover': true,
      'ready': this.props.ready,
      'error': this.props.error,
      'slow': this.state.slow,
    });

    let message = this.props.error;
    if (this.props.error) {
      message = this.props.error;
    } else if (this.state.slow) {
      message = "Still trying to reach Nylas…";
    } else {
      message = '&nbsp;'
    }

    return (
      <div className={classes}>
        <div style={{flex: 1}} />
        <RetinaImg
          className="spinner"
          style={{width: 20, height: 20}}
          name="inline-loading-spinner.gif"
          mode={RetinaImg.Mode.ContentPreserve}
        />
        <div className="message">{message}</div>
        <div className="btn try-again" onClick={this.props.onTryAgain}>Try Again</div>
        <div style={{flex: 1}} />
      </div>
    );
  }
}

export default class AuthenticatePage extends React.Component {
  static displayName = "AuthenticatePage";

  static propTypes = {
    accountInfo: React.PropTypes.object,
  };

  constructor(props) {
    super(props);
    this.state = {
      ready: false,
      error: null,
    };
  }

  componentDidMount() {
    const webview = ReactDOM.findDOMNode(this.refs.webview);
    webview.src = `${IdentityStore.URLRoot}/onboarding`;
    webview.addEventListener('did-start-loading', this.webviewDidStartLoading);
    webview.addEventListener('did-fail-load', this.webviewDidFailLoad);
    webview.addEventListener('did-finish-load', this.webviewDidFinishLoad);
    webview.addEventListener('console-message', (e) => {
      console.log('Guest page logged a message:', e.message);
    });
  }

  onTryAgain = () => {
    const webview = ReactDOM.findDOMNode(this.refs.webview);
    webview.reload();
  }

  webviewDidStartLoading = () => {
    this.setState({error: null, webviewLoading: true});
  }

  webviewDidFailLoad = ({errorCode, errorDescription, validatedURL}) => {
    // "Operation was aborted" can be fired when we move between pages quickly.
    if (errorCode === -3) {
      return;
    }

    let error = errorDescription;
    if (!error) {
      const e = networkErrors.createByCode(errorCode);
      error = `Could not reach ${validatedURL}. ${e ? e.message : errorCode}`;
    }
    this.setState({ready: false, error: error, webviewLoading: false});
  }

  webviewDidFinishLoad = () => {
    // this is sometimes called right after did-fail-load
    if (this.state.error) { return; }

    const js = `
      var a = document.querySelector('#pro-account');
      result = a ? a.innerText : null;
    `;

    const webview = ReactDOM.findDOMNode(this.refs.webview);
    webview.executeJavaScript(js, false, (result) => {
      this.setState({ready: true, webviewLoading: false});
      if (result !== null) {
        OnboardingActions.authenticationJSONReceived(JSON.parse(result));
      }
    });
  }

  render() {
    return (
      <div className="page authenticate">
        <webview ref="webview"></webview>
        <div className={`webview-loading-spinner loading-${this.state.webviewLoading}`}>
          <RetinaImg
            style={{width: 20, height: 20}}
            name="inline-loading-spinner.gif"
            mode={RetinaImg.Mode.ContentPreserve}
          />
        </div>
        <InitialLoadingCover
          ready={this.state.ready}
          error={this.state.error}
          onTryAgain={this.onTryAgain}
        />
      </div>
    );
  }
}
