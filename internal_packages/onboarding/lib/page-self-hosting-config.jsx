import React from 'react'
import {Actions} from 'nylas-exports'
import {Flexbox} from 'nylas-component-kit'
import OnboardingActions from './onboarding-actions'


class SelfHostingConfigPage extends React.Component {
  static displayName = 'SelfHostingConfigPage'

  static propTypes = {
    addAccount: React.PropTypes.bool,
  }

  constructor(props) {
    super(props)
    this.state = {
      url: "",
      port: "",
      error: null,
    }
  }

  _onChangeUrl = (event) => {
    this.setState({
      url: event.target.value,
    })
  }

  _onChangePort = (event) => {
    this.setState({
      port: event.target.value,
    })
  }

  _addAccountJSON = () => {
    // Connect to local sync engine's /accounts endpoint and add accounts to N1
    const xmlHttp = new XMLHttpRequest()
    xmlHttp.onreadystatechange = () => {
      if (xmlHttp.readyState === 4 && xmlHttp.status === 200) {
        const accounts = JSON.parse(xmlHttp.responseText)
        if (accounts.length === 0) {
          this.setState({error: "There are no accounts added to this instance of the sync engine. Make sure you've authed an account."})
        }
        OnboardingActions.accountsAddedLocally(accounts)
      }
    }
    xmlHttp.onerror = () => {
      this.setState({error: `The request to ${NylasEnv.config.get('syncEngine.APIRoot')}/accounts failed.`})
    }
    xmlHttp.open("GET", `${NylasEnv.config.get('syncEngine.APIRoot')}/accounts`)
    xmlHttp.send(null)
  }

  _onSubmit = () => {
    if (this.state.url.length === 0 || this.state.port.length === 0) {
      this.setState({error: "Please include both a URL and port number."})
      return
    }
    NylasEnv.config.set('env', 'custom')
    NylasEnv.config.set('syncEngine.APIRoot', `http://${this.state.url}:${this.state.port}`)
    Actions.setNylasIdentity({
      token: "SELFHOSTEDSYNCENGINE",
      identity: {
        firstname: "",
        lastname: "",
        valid_until: null,
        free_until: Number.INT_MAX,
        email: "",
        id: 1,
        seen_welcome_page: true,
      },
    })
    this._addAccountJSON()
  }

  _onKeyDown = (event) => {
    if (['Enter', 'Return'].includes(event.key)) {
      this._onSubmit();
    }
  }

  _renderInitalConfig() {
    return (
      <div>
        <h2>Configure your self-hosted sync engine</h2>
        <div className="message empty">
          Once you have created your instance of the sync engine, connect it to N1.
        </div>
      </div>
    )
  }

  _renderAdditionalConfig() {
    return (
      <div>
        <h2>Connect more email accounts</h2>
        <div className="message empty">
          To add new accounts, use the <a href="https://github.com/nylas/sync-engine#installation-and-setup">instructions</a> for the Sync Engine. For example:<br />
          <code>bin/inbox-auth you@gmail.com</code>
        </div>
      </div>
    )
  }

  _renderErrorMessage() {
    return (
      <div className="message error">
        {this.state.error}
      </div>
    )
  }

  render() {
    return (
      <div className="page self-hosting">
        {!this.props.addAccount ? this._renderInitalConfig() : this._renderAdditionalConfig()}
        {this.state.error ? this._renderErrorMessage() : null}
        <div className="self-hosting-container">
          <Flexbox direction="horizontal">
            <div className="api-root">
              <h4>{`http://`}</h4>
            </div>
            <div>
              <label>Sync Engine URL:</label>
              <input
                title="Sync Engine URL"
                type="text"
                value={this.state.url}
                onChange={this._onChangeUrl}
                onKeyDown={this._onKeyDown}
              />
            </div>
            <div className="api-root">
              <h4>{`:`}</h4>
            </div>
            <div>
              <label>Sync Engine Port:</label>
              <input
                title="Sync Engine Port"
                type="text"
                value={this.state.port}
                onChange={this._onChangePort}
                onKeyDown={this._onKeyDown}
              />
            </div>
          </Flexbox>
        </div>
        <button
          className="btn btn-large btn-gradient"
          onClick={this._onSubmit}
        >
          Connect Accounts
        </button>
      </div>
    )
  }
}

export default SelfHostingConfigPage
