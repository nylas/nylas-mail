import React from 'react';
import {ipcRenderer, shell} from 'electron';
import {RetinaImg} from 'nylas-component-kit';

const clipboard = require('electron').clipboard


export default class OAuthSignInPage extends React.Component {
  static displayName = "OAuthSignInPage";

  static propTypes = {
    authUrl: React.PropTypes.string,
    iconName: React.PropTypes.string,
    makeRequest: React.PropTypes.func,
    onSuccess: React.PropTypes.func,
    serviceName: React.PropTypes.string,
    sessionKey: React.PropTypes.string,
  };

  constructor() {
    super()
    this.state = {
      showAlternative: false,
    }
  }

  componentDidMount() {
    // Show the "Sign in to ..." prompt for a moment before bouncing
    // to URL. (400msec animation + 200msec to read)
    this._pollTimer = null;
    this._startTimer = setTimeout(() => {
      shell.openExternal(this.props.authUrl);
      this.startPollingForResponse();
    }, 600);
    setTimeout(() => {
      this.setState({showAlternative: true})
    }, 1500);
  }

  componentWillUnmount() {
    if (this._startTimer) clearTimeout(this._startTimer);
    if (this._pollTimer) clearTimeout(this._pollTimer);
  }

  startPollingForResponse() {
    let delay = 1000;
    let onWindowFocused = null;
    let poll = null;

    onWindowFocused = () => {
      delay = 1000;
      if (this._pollTimer) {
        clearTimeout(this._pollTimer);
        this._pollTimer = setTimeout(poll, delay);
      }
    };

    poll = () => {
      this.props.makeRequest(this.props.sessionKey, (err, json) => {
        clearTimeout(this._pollTimer);
        if (json) {
          ipcRenderer.removeListener('browser-window-focus', onWindowFocused);
          this.props.onSuccess(json);
        } else {
          delay = Math.min(delay * 1.2, 10000);
          this._pollTimer = setTimeout(poll, delay);
        }
      });
    }

    ipcRenderer.on('browser-window-focus', onWindowFocused);
    this._pollTimer = setTimeout(poll, 5000);
  }


  _renderAlternative() {
    let classnames = "input hidden"
    if (this.state.showAlternative) {
      classnames += " fadein"
    }

    return (
      <div className={classnames}>
        <div style={{marginTop: 40}}>
          Page didn't open? Paste this URL into your browser:
        </div>
        <input
          type="url"
          className="url-copy-target"
          value={this.props.authUrl}
          readOnly
        />
        <div
          className="copy-to-clipboard"
          onClick={() => clipboard.writeText(this.props.authUrl)}
          onMouseDown={() => this.setState({pressed: true})}
          onMouseUp={() => this.setState({pressed: false})}
        >
          <RetinaImg
            name="icon-copytoclipboard.png"
            mode={RetinaImg.Mode.ContentIsMask}
          />
        </div>
      </div>
    )
  }


  render() {
    return (
      <div className={`page account-setup ${this.props.serviceName.toLowerCase()}`}>
        <div className="logo-container">
          <RetinaImg
            name={this.props.iconName}
            mode={RetinaImg.Mode.ContentPreserve}
            className="logo"
          />
        </div>
        <h2>
          Sign in to {this.props.serviceName} in<br />your browser.
        </h2>
        <div className="alternative-auth">
          {this._renderAlternative()}
        </div>
      </div>
    );
  }
}
