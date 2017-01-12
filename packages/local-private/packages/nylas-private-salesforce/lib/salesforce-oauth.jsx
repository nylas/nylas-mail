import {shell} from 'electron'
import crypto from 'crypto';
import {Actions, NylasAPIRequest, React, KeyManager} from 'nylas-exports'

const ACCESS_TOKEN_KEY_NAME = 'Nylas Salesforce Token';
const REFRESH_TOKEN_KEY_NAME = 'Nylas Salesforce Refresh Token';

class SalesforceOAuth {
  constructor() {
    this._onConfigChanged()
    this._resetDelay()
    this.MAX_POLLS = 100;
    this._connectionAttempt = 0
  }

  activate() {
    this._usub = NylasEnv.config.onDidChange('env', this._onConfigChanged)
  }

  deactivate() {
    this._usub.dispose()
  }

  connect() {
    if (NylasEnv.getLoadSettings().isSpec) { return Promise.resolve() }
    this._connectionAttempt += 1
    this._resetDelay()
    Actions.recordUserEvent("Salesforce Connect Started")
    shell.openExternal(`${this.APIRoot}/connect/salesforce?state=${this.state}`)
    this._numPolls = 0;
    return this._pollForToken(this._connectionAttempt)
  }

  fetchNewToken() {
    const req = new NylasAPIRequest({
      api: this,
      options: {
        path: `/salesforce/token/refresh`,
        method: "POST",
        body: {refresh_token: this.refreshToken()},
        auth: {user: "", pass: "", sendImmediately: true},
      },
    });
    return req.run().then((tokenData) => {
      const configData = this._extractAndSetTokens(tokenData)

      const oldConfig = NylasEnv.config.get("salesforce") || {}
      NylasEnv.config.set("salesforce", Object.assign({}, oldConfig, configData))
      Actions.recordUserEvent("Salesforce Token Refreshed", {
        instanceUrl: configData.instance_url,
      })
    })
  }

  clearTokens() {
    KeyManager.deletePassword(ACCESS_TOKEN_KEY_NAME);
    KeyManager.deletePassword(REFRESH_TOKEN_KEY_NAME);
  }

  accessToken() {
    return KeyManager.getPassword(ACCESS_TOKEN_KEY_NAME, {migrateFromService: "Nylas Salesforce"})
  }

  refreshToken() {
    return KeyManager.getPassword(REFRESH_TOKEN_KEY_NAME, {migrateFromService: "Nylas Salesforce"})
  }

  _resetDelay() {
    this.state = (new Buffer(crypto.randomBytes(40))).toString('base64');
    this.delay = 1000;
    if (this.currentTimeout) clearTimeout(this.currentTimeout);
  }

  _onConfigChanged = () => {
    const env = NylasEnv.config.get('env')
    if (['development', 'local'].includes(env)) {
      this.APIRoot = "http://localhost:3000"
    } else if (env === 'staging') {
      this.APIRoot = "https://nylas-salesforce.herokuapp.com"
    } else {
      this.APIRoot = "https://nylas-salesforce.herokuapp.com"
    }
  }

  _onConnection = (tokenData) => {
    Actions.recordUserEvent("Salesforce Connected", {
      instanceUrl: tokenData.instance_url,
    })

    const configData = this._extractAndSetTokens(tokenData)

    NylasEnv.config.set("salesforce", configData)

    NylasEnv.show()
    Actions.openModal({
      component: (
        <div className="salesforce-welcome" tabIndex="0">
          <h2>Success! Nylas Mail and Salesforce are now connected.</h2>
          <p>Select a message to create or edit contact and lead records or to sync the thread with an opportunity. Here&rsquo;s how it works!</p>
          <iframe width="560" height="315" src="https://www.youtube.com/embed/5ziK7lCdTjA" />
        </div>
      ),
      height: 520,
      width: 700,
    })
  }

  _extractAndSetTokens = (tokenData) => {
    const clonedData = Object.assign({}, tokenData);
    const accessToken = tokenData.access_token
    const refreshToken = tokenData.refresh_token
    delete clonedData.access_token
    delete clonedData.refresh_token

    if (accessToken) {
      KeyManager.replacePassword(ACCESS_TOKEN_KEY_NAME, accessToken)
    }

    if (refreshToken) {
      KeyManager.replacePassword(REFRESH_TOKEN_KEY_NAME, refreshToken)
    }

    return clonedData
  }

  _pollForToken(connectionAttempt) {
    const req = new NylasAPIRequest({
      api: this,
      options: {
        auth: {user: "", pass: "", sendImmediately: true},
        path: `/salesforce/token?state=${this.state}`,
      },
    });
    return req.run()
    .then(this._onConnection)
    .catch((apiError) => {
      if (apiError.statusCode === 404) {
        if (this._connectionAttempt === connectionAttempt) {
          return this._tryAgain(() => this._pollForToken(connectionAttempt))
        }
        return Promise.resolve()
      }
      return Promise.reject(apiError)
    })
  }

  _tryAgain(fn) {
    return new Promise((resolve, reject) => {
      if (this._numPolls > this.MAX_POLLS) {
        reject()
        return
      }
      this.currentTimeout = setTimeout(() => {
        fn.call(this).then(resolve).catch(reject)
      }, this.delay);
    })
  }
}

export default new SalesforceOAuth();
