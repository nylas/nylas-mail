import NylasStore from 'nylas-store';
import {ipcRenderer} from 'electron';
import request from 'request';
import url from 'url'

import KeyManager from '../../key-manager'
import Actions from '../actions';
import AccountStore from './account-store';
import Utils from '../models/utils';

const configIdentityKey = "nylas.identity";

// Note this key name is used when migrating to Nylas Pro accounts from
// old N1.
const KEY_NAME = 'Nylas Account';

class IdentityStore extends NylasStore {

  constructor() {
    super();

    NylasEnv.config.onDidChange('env', this._onEnvChanged);
    this._onEnvChanged();

    this.listenTo(AccountStore, () => { this.trigger() });
    this.listenTo(Actions.setNylasIdentity, this._onSetNylasIdentity);
    this.listenTo(Actions.logoutNylasIdentity, this._onLogoutNylasIdentity);

    NylasEnv.config.onDidChange(configIdentityKey, () => {
      this._loadIdentity();
      this.trigger();
      if (NylasEnv.isMainWindow()) {
        this.refreshAccounts();
      }
    });

    this._loadIdentity();

    if (NylasEnv.isMainWindow() && ['staging', 'production'].includes(NylasEnv.config.get('env'))) {
      setInterval(this.refreshIdentityAndAccounts, 1000 * 60 * 60); // 1 hour
      this.refreshIdentityAndAccounts();
    }
  }

  _onEnvChanged = () => {
    const env = NylasEnv.config.get('env')
    if (['development', 'local'].includes(env)) {
      this.URLRoot = "http://billing.lvh.me:5555";
    } else if (env === 'experimental') {
      this.URLRoot = "https://billing-experimental.nylas.com";
    } else if (env === 'staging') {
      this.URLRoot = "https://billing-staging.nylas.com";
    } else {
      this.URLRoot = "https://billing.nylas.com";
    }
  }

  _loadIdentity() {
    this._identity = NylasEnv.config.get(configIdentityKey);
    if (this._identity) {
      this._identity.token = KeyManager.getPassword(KEY_NAME, {migrateFromService: "Nylas"});
    }
  }

  identity() {
    return this._identity;
  }

  identityId() {
    if (!this._identity) {
      return null;
    }
    return this._identity.id;
  }

  refreshIdentityAndAccounts = () => {
    return this.fetchIdentity().then(() =>
      this.refreshAccounts()
    ).catch((err) => {
      console.error(`Unable to refresh IdentityStore status: ${err.message}`)
    });
  }

  refreshAccounts = () => {
    const accountIds = AccountStore.accounts().map((a) => a.id);
    AccountStore.refreshHealthOfAccounts(accountIds);
    Actions.refreshAllDeltaConnections()
    this.trigger();
  }

  /**
   * This passes utm_source, utm_campaign, and utm_content params to the
   * N1 billing site. Please reference:
   * https://paper.dropbox.com/doc/Analytics-ID-Unification-oVDTkakFsiBBbk9aeuiA3
   * for the full list of utm_ labels.
   */
  fetchSingleSignOnURL(path, {source, campaign, content}) {
    if (!this._identity) {
      return Promise.reject(new Error("fetchSingleSignOnURL: no identity set."));
    }

    const qs = {utm_medium: "N1"}
    if (source) { qs.utm_source = source }
    if (campaign) { qs.utm_campaign = campaign }
    if (content) { qs.utm_content = content }

    let pathWithUtm = url.parse(path, true);
    pathWithUtm.query = Object.assign({}, qs, (pathWithUtm.query || {}));
    pathWithUtm = url.format({
      pathname: pathWithUtm.pathname,
      query: pathWithUtm.query,
    })

    if (!pathWithUtm.startsWith('/')) {
      return Promise.reject(new Error("fetchSingleSignOnURL: path must start with a leading slash."));
    }

    return new Promise((resolve) => {
      request({
        method: 'POST',
        url: `${this.URLRoot}/n1/login-link`,
        qs: qs,
        json: true,
        timeout: 1500,
        body: {
          next_path: pathWithUtm,
          account_token: this._identity.token,
        },
      }, (error, response = {}, body) => {
        if (error || !body.startsWith('http')) {
          // Single-sign on attempt failed. Rather than churn the user right here,
          // at least try to open the page directly in the browser.
          resolve(`${this.URLRoot}${path}`);
        } else {
          resolve(body);
        }
      });
    });
  }

  fetchIdentity = () => {
    if (!this._identity || !this._identity.token) {
      return Promise.resolve();
    }
    return this.fetchPath('/n1/user').then((json) => {
      const nextIdentity = Object.assign({}, this._identity, json);
      this._onSetNylasIdentity(nextIdentity);
    });
  }

  fetchPath = (path) => {
    return new Promise((resolve, reject) => {
      const requestId = Utils.generateTempId();
      const options = {
        method: 'GET',
        url: `${this.URLRoot}${path}`,
        startTime: Date.now(),
        auth: {
          username: this._identity.token,
          password: '',
          sendImmediately: true,
        },
      };

      Actions.willMakeAPIRequest({
        request: options,
        requestId: requestId,
      });
      request(options, (error, response = {}, body) => {
        Actions.didMakeAPIRequest({
          request: options,
          statusCode: response.statusCode,
          error: error,
          requestId: requestId,
        });
        if (response.statusCode === 200) {
          try {
            return resolve(JSON.parse(body));
          } catch (err) {
            NylasEnv.reportError(new Error(`IdentityStore.fetchPath: ${path} ${err.message}.`))
          }
        }
        return reject(error || new Error(`IdentityStore.fetchPath: ${path} ${response.statusCode}.`));
      });
    });
  }

  _onLogoutNylasIdentity = () => {
    KeyManager.deletePassword(KEY_NAME);
    NylasEnv.config.unset(configIdentityKey);
    ipcRenderer.send('command', 'application:relaunch-to-initial-windows');
  }

  _onSetNylasIdentity = (identity) => {
    if (identity.token) {
      KeyManager.replacePassword(KEY_NAME, identity.token)
      delete identity.token;
    }
    NylasEnv.config.set(configIdentityKey, identity);
  }
}

export default new IdentityStore()
