import NylasStore from 'nylas-store';
import {remote} from 'electron';
import url from 'url'

import Utils from '../models/utils';
import Actions from '../actions';
import {APIError} from '../errors';
import KeyManager from '../../key-manager';

// Note this key name is used when migrating to Nylas Pro accounts from old N1.
const KEYCHAIN_NAME = 'Nylas Account';

class IdentityStore extends NylasStore {

  constructor() {
    super();
    this._identity = null;
  }

  async activate() {
    if (NylasEnv.isEmptyWindow()) {
      NylasEnv.onWindowPropsReceived(() => {
        this.deactivate();
        this.activate();
      })
      return
    }

    NylasEnv.config.onDidChange('env', this._onEnvChanged);
    this._onEnvChanged();

    NylasEnv.config.onDidChange('nylasid', this._onIdentityChanged);
    this._onIdentityChanged();

    this.listenTo(Actions.logoutNylasIdentity, this._onLogoutNylasIdentity);
    this._fetchAndPollRemoteIdentity()
  }

  deactivate() {
    if (this._disp) this._disp.dispose();
    this.stopListeningToAll()
  }

  identity() {
    if (!this._identity || !this._identity.id) return null
    return Utils.deepClone(this._identity);
  }

  hasProAccess() {
    return this._identity && this._identity.has_pro_access
  }

  identityId() {
    if (!this._identity) {
      return null;
    }
    return this._identity.id;
  }

  _fetchAndPollRemoteIdentity() {
    if (!NylasEnv.isMainWindow()) return;
    /**
     * We only need to re-fetch the identity to synchronize ourselves
     * with any changes a user did on a separate computer. Any updates
     * they do on their primary computer will be optimistically updated.
     * We also update from the server's version every
     * `SendFeatureUsageEventTask`
     */
    setInterval(this._fetchIdentity.bind(this), 1000 * 60 * 10); // 10 minutes
    // Don't await for this!
    this._fetchIdentity();
  }

  /**
   * Saves the identity to the database. The local cache will be updated
   * once the database change comes back through
   */
  async saveIdentity(identity) {
    this._identity = identity;

    if (identity && identity.token) {
      KeyManager.replacePassword(KEYCHAIN_NAME, identity.token);
      delete identity.token;
    }
    if (!identity) {
      KeyManager.deletePassword(KEYCHAIN_NAME);
    }
    NylasEnv.config.set('nylasid', identity);
  }

  /**
   * When the identity changes in the database, update our local store
   * cache and set the token from the keychain.
   */
  _onIdentityChanged = () => {
    this._identity = NylasEnv.config.get('nylasid') || {};
    if (!this._identity.token) {
      this._identity.token = KeyManager.getPassword(KEYCHAIN_NAME);
    }
    this.trigger();
  }

  _onLogoutNylasIdentity = async () => {
    await this.saveIdentity(null)
    // We need to relaunch the app to clear the webview session
    // and prevent the webview from re signing in with the same NylasID
    remote.app.relaunch()
    remote.app.quit()
  }

  _onEnvChanged = () => {
    const env = NylasEnv.config.get('env')
    if (['development', 'local'].includes(env)) {
      if (process.env.BILLING_URL) {
        this.URLRoot = process.env.BILLING_URL;
      } else {
        this.URLRoot = "https://billing-staging.nylas.com";
      }
    } else if (env === 'experimental') {
      this.URLRoot = "https://billing-experimental.nylas.com";
    } else if (env === 'staging') {
      this.URLRoot = "https://billing-staging.nylas.com";
    } else {
      this.URLRoot = "https://billing.nylas.com";
    }
  }

  /**
   * This passes utm_source, utm_campaign, and utm_content params to the
   * N1 billing site. Please reference:
   * https://paper.dropbox.com/doc/Analytics-ID-Unification-oVDTkakFsiBBbk9aeuiA3
   * for the full list of utm_ labels.
   */
  async fetchSingleSignOnURL(path, {source, campaign, content} = {}) {
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
      throw new Error("fetchSingleSignOnURL: path must start with a leading slash.");
    }

    const body = new FormData();
    for (const key of Object.keys(qs)) {
      body.append(key, qs[key]);
    }
    body.append('next_path', pathWithUtm);
    body.append('account_token', this._identity.token);

    const resp = await fetch(`${this.URLRoot}/n1/login-link`, {
      method: 'POST',
      qs: qs,
      timeout: 1500,
      body: body,
    });
    if (resp.ok) {
      const text = await resp.text();
      if (text.startsWith('http')) {
        return text;
      }
    }
    return `${this.URLRoot}${path}`;
  }

  async asyncRefreshIdentity() {
    await this._fetchIdentity();
    return true
  }

  async _fetchIdentity() {
    if (!this._identity || !this._identity.token) {
      return Promise.resolve();
    }
    const json = await this.fetchPath('/n1/user');
    if (!json || !json.id || json.id !== this._identity.id) {
      console.error(json)
      NylasEnv.reportError(new Error("Remote Identity returned invalid json"), json || {})
      return Promise.resolve(this._identity)
    }
    const nextIdentity = Object.assign({}, this._identity, json);
    return this.saveIdentity(nextIdentity);
  }

  fetchPath = async (path) => {
    const options = {
      method: 'GET',
      url: `${this.URLRoot}${path}`,
      startTime: Date.now(),
    };
    try {
      const newIdentity = await this.nylasIDRequest(options);
      return newIdentity
    } catch (err) {
      const error = err || new Error(`IdentityStore.fetchPath: ${path} ${err.message}.`)
      NylasEnv.reportError(error)
      return null
    }
  }

  async nylasIDRequest(options) {
    options.credentials = 'include';
    options.headers = new Headers();
    options.headers.set('Authorization', `Basic ${btoa(`${this._identity.token}:`)}`)
    const resp = await fetch(options.url, options);
    if (!resp.ok) {
      throw new Error(resp.statusText);
    }
    return resp.json();
  }
}

export default new IdentityStore()
