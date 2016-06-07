import NylasStore from 'nylas-store';
import keytar from 'keytar';
import {ipcRenderer} from 'electron';
import request from 'request';
import url from 'url'

import Actions from '../actions';
import AccountStore from './account-store';

const configIdentityKey = "nylas.identity";
const keytarServiceName = 'Nylas';
const keytarIdentityKey = 'Nylas Account';

const State = {
  Trialing: 'Trialing',
  Valid: 'Valid',
  Lapsed: 'Lapsed',
};

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
    });

    this._loadIdentity();

    if (NylasEnv.isWorkWindow() && ['staging', 'production'].includes(NylasEnv.config.get('env'))) {
      setInterval(this.refreshStatus, 1000 * 60 * 60);
      this.refreshStatus();
    }
  }

  _onEnvChanged = () => {
    const env = NylasEnv.config.get('env')
    if (['development', 'local'].includes(env)) {
      this.URLRoot = "http://localhost:5009";
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
      this._identity.token = keytar.getPassword(keytarServiceName, keytarIdentityKey);
    }
  }

  get State() {
    return State;
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

  subscriptionState() {
    if (!this._identity || (this._identity.valid_until === null)) {
      return State.Trialing;
    }
    if (new Date(this._identity.valid_until) < new Date()) {
      return State.Lapsed;
    }
    return State.Valid;
  }

  trialDaysRemaining() {
    const daysToDate = (date) =>
      Math.max(0, Math.round((date.getTime() - Date.now()) / (1000 * 24 * 60 * 60)))

    if (this.subscriptionState() !== State.Trialing) {
      return null;
    }

    // Return the smallest number of days left in any linked account, or null
    // if no trialExpirationDate is present on any account.
    return AccountStore.accounts().map((a) =>
      (a.subscriptionRequiredAfter ? daysToDate(a.subscriptionRequiredAfter) : null)
    ).sort().shift();
  }

  refreshStatus = () => {
    if (!this._identity || !this._identity.token) {
      return;
    }
    request({
      method: 'GET',
      url: `${this.URLRoot}/n1/user`,
      auth: {
        username: this._identity.token,
        password: '',
        sendImmediately: true,
      },
    }, (error, response = {}, body) => {
      if (response.statusCode === 200) {
        try {
          const nextIdentity = Object.assign({}, this._identity, JSON.parse(body));
          this._onSetNylasIdentity(nextIdentity)
        } catch (err) {
          NylasEnv.reportError("IdentityStore.refreshStatus: invalid JSON in response body.")
        }
      }
    });
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

    const pathWithUtm = url.parse(path);
    pathWithUtm.query = Object.assign({}, qs, (pathWithUtm.query || {}))

    if (!pathWithUtm.startsWith('/')) {
      return Promise.reject(new Error("fetchSingleSignOnURL: path must start with a leading slash."));
    }

    return new Promise((resolve) => {
      request({
        method: 'POST',
        url: `${this.URLRoot}/n1/login-link`,
        qs: qs,
        json: true,
        body: {
          next_path: pathWithUtm.format(),
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

  _onLogoutNylasIdentity = () => {
    keytar.deletePassword(keytarServiceName, keytarIdentityKey);
    NylasEnv.config.unset(configIdentityKey);
    ipcRenderer.send('command', 'application:relaunch-to-initial-windows');
  }

  _onSetNylasIdentity = (identity) => {
    keytar.replacePassword(keytarServiceName, keytarIdentityKey, identity.token);
    delete identity.token;
    NylasEnv.config.set(configIdentityKey, identity);
  }
}

export default new IdentityStore()
