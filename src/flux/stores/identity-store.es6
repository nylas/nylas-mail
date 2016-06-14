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

    this._subscriptionRequiredAfter = null;

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

  daysUntilSubscriptionRequired() {
    if (!this._subscriptionRequiredAfter) {
      return null;
    }
    return Math.max(0, Math.round((this._subscriptionRequiredAfter.getTime() - Date.now()) / (1000 * 24 * 60 * 60)));
  }

  refreshStatus = () => {
    return Promise.all([
      this.fetchIdentity(),
      Promise.all(AccountStore.accounts().map((a) =>
        this.fetchSubscriptionRequiredDate(a))
      ).then((subscriptionRequriedDates) => {
        this._subscriptionRequiredAfter = subscriptionRequriedDates.sort().shift();
      }),
    ]).catch((err) => {
      console.error(`Unable to refresh IdentityStore status: ${err.message}`)
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

  fetchSubscriptionRequiredDate = (account) => {
    return this.fetchPath(`/n1/account/${account.id}`).then((json) => {
      const date = json.subscription_required_after ? new Date(json.subscription_required_after) : null;
      Promise.resolve(date);
    });
  }

  fetchIdentity = () => {
    if (!this._identity || !this._identity.token) {
      return Promise.resolve();
    }
    return this.fetchPath('/n1/user').then((json) => {
      const nextIdentity = Object.assign({}, this._identity, json);
      this._onSetNylasIdentity(nextIdentity)
    });
  }

  fetchPath = (path) => {
    return new Promise((resolve, reject) => {
      request({
        method: 'GET',
        url: `${this.URLRoot}${path}`,
        auth: {
          username: this._identity.token,
          password: '',
          sendImmediately: true,
        },
      }, (error, response = {}, body) => {
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
