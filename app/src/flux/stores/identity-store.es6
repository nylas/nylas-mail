import NylasStore from 'nylas-store';
import {remote} from 'electron';
import url from 'url'

import Utils from '../models/utils';
import Actions from '../actions';
import KeyManager from '../../key-manager';
import {makeRequest, rootURLForServer} from '../nylas-api-request';

// Note this key name is used when migrating to Nylas Pro accounts from old N1.
const KEYCHAIN_NAME = 'Mailspring Account';

class IdentityStore extends NylasStore {

  constructor() {
    super();
    this._identity = null;

    if (NylasEnv.isEmptyWindow()) {
      /*
      Hot windows don't receive any action-bridge-messages, which include DB updates.
      Since the hot window loads first, it may have a stale verison of the Identity.
      */
      NylasEnv.onWindowPropsReceived(() => {
        this._onIdentityChanged();
      })
      return
    }

    NylasEnv.config.onDidChange('identity', this._onIdentityChanged);
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

  identityId() {
    if (!this._identity) {
      return null;
    }
    return this._identity.id;
  }

  _fetchAndPollRemoteIdentity() {
    if (!NylasEnv.isMainWindow()) return;
    setTimeout(() => { this.fetchIdentity(); }, 1000);
    setInterval(() => { this.fetchIdentity(); }, 1000 * 60 * 10); // 10 minutes
  }

  saveIdentity(identity) {
    if (!identity) {
      this._identity = null;
      KeyManager.deletePassword(KEYCHAIN_NAME);
      NylasEnv.config.set('identity', null);
      return;
    }

    const {token, ...rest} = identity;

    // allow someone to call saveIdentity without the token,
    // and only save it if it's been changed (expensive call.)
    const nextToken = token || this._identity.token;
    if (nextToken && nextToken !== this._identity.token) {
      KeyManager.replacePassword(KEYCHAIN_NAME, nextToken);
    }

    this._identity = identity;
    this._identity.token = nextToken;
    NylasEnv.config.set('identity', rest);

    // Setting NylasEnv.config will trigger our onDidChange handler,
    // no need to trigger here.
  }

  /**
   * When the identity changes in the database, update our local store
   * cache and set the token from the keychain.
   */
  _onIdentityChanged = () => {
    this._identity = NylasEnv.config.get('identity') || {};
    this._identity.token = KeyManager.getPassword(KEYCHAIN_NAME);
    this.trigger();
  }

  _onLogoutNylasIdentity = () => {
    this.saveIdentity(null)
    // We need to relaunch the app to clear the webview session
    // and prevent the webview from re signing in with the same NylasID
    remote.app.relaunch()
    remote.app.quit()
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

    try {
      const json = await makeRequest({
        server: 'identity',
        path: '/api/login-link',
        qs: qs,
        body: body,
        timeout: 1500,
        method: 'POST',
      });
      return `${rootURLForServer('identity')}${json.path}`;
    } catch (err) {
      return `${rootURLForServer('identity')}${path}`;
    }
  }

  async fetchIdentity() {
    if (!this._identity || !this._identity.token) {
      return null;
    }

    const json = await makeRequest({
      server: 'identity',
      path: '/api/me',
      method: 'GET',
    });

    if (!json || !json.id || json.id !== this._identity.id) {
      console.error(json);
      NylasEnv.reportError(new Error("Remote Identity returned invalid json"), json || {})
      return this._identity;
    }
    const nextIdentity = Object.assign({}, this._identity, json);
    this.saveIdentity(nextIdentity);
    return this._identity;
  }
}

export default new IdentityStore()
