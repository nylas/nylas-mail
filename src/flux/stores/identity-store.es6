import Rx from 'rx-lite'
import NylasStore from 'nylas-store';
import {ipcRenderer} from 'electron';
import request from 'request';
import url from 'url'

import Utils from '../models/utils';
import Actions from '../actions';
import KeyManager from '../../key-manager'
import DatabaseStore from './database-store'

// Note this key name is used when migrating to Nylas Pro accounts from
// old N1.
const KEYCHAIN_NAME = 'Nylas Account';

class IdentityStore extends NylasStore {

  constructor() {
    super();
    this._savePromises = []
    this._identity = null
  }

  async activate() {
    NylasEnv.config.onDidChange('env', this._onEnvChanged);
    this._onEnvChanged();

    this.listenTo(Actions.logoutNylasIdentity, this._onLogoutNylasIdentity);

    const q = DatabaseStore.findJSONBlob("NylasID");
    this._disp = Rx.Observable.fromQuery(q).subscribe(this._onIdentityChanged)

    const identity = await DatabaseStore.run(q)
    this._onIdentityChanged(identity)

    this._fetchAndPollRemoteIdentity()
  }

  deactivate() {
    this._disp.dispose();
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
    if (!['staging', 'production'].includes(NylasEnv.config.get('env'))) return;
    /**
     * We only need to re-fetch the identity to synchronize ourselves
     * with any changes a user did on a separate computer. Any updates
     * they do on their primary computer will be optimistically updated.
     * We also update from the server's version every
     * `SendFeatureUsageEventTask`
     */
    setInterval(this._fetchIdentity, 1000 * 60 * 10); // 10 minutes
    // Don't await for this!
    this._fetchIdentity();
  }

  /**
   * Saves the identity to the database. The local cache will be updated
   * once the database change comes back through
   */
  async saveIdentity(identity) {
    if (identity && identity.token) {
      KeyManager.replacePassword(KEYCHAIN_NAME, identity.token)
      delete identity.token;
    }
    if (!identity) {
      KeyManager.deletePassword(KEYCHAIN_NAME)
    }
    const savePromise = new Promise((resolve, reject) => {
      this._savePromises.push({
        resolve: resolve,
        rejectTimeout: setTimeout(() => {
          reject(new Error("Identity never persisted to database"))
        }, 10000),
      });
    })
    await DatabaseStore.inTransaction((t) => {
      return t.persistJSONBlob("NylasID", identity)
    });
    return savePromise
  }

  /**
   * When the identity changes in the database, update our local store
   * cache and set the token from the keychain.
   */
  _onIdentityChanged = (newIdentity) => {
    const oldId = ((this._identity || {}).id)
    this._identity = newIdentity
    if (this._identity && this._identity.id) {
      if (!this._identity.token) {
        this._identity.token = KeyManager.getPassword(KEYCHAIN_NAME);
      }
    } else {
      // It's possible the identity exists as an empty object. If the
      // object looks blank, set the identity to null.
      this._identity = null
    }
    const newId = ((this._identity || {}).id);
    if (oldId !== newId) {
      ipcRenderer.send('command', 'onIdentityChanged');
    }
    if (this._savePromises.length > 0) {
      for (const {resolve, rejectTimeout} of this._savePromises) {
        resolve();
        clearTimeout(rejectTimeout)
      }
      this._savePromises = []
    }
    this.trigger();
  }

  _onLogoutNylasIdentity = async () => {
    await this.saveIdentity(null)
    ipcRenderer.send('command', 'application:relaunch-to-initial-windows');
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

  _fetchIdentity = async () => {
    if (!this._identity || !this._identity.token) {
      return Promise.resolve();
    }
    const json = await this.fetchPath('/n1/user')
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

  nylasIDRequest(options) {
    return new Promise((resolve, reject) => {
      options.formData = false
      options.json = true
      options.auth = {
        username: this._identity.token,
        password: '',
        sendImmediately: true,
      }
      const requestId = Utils.generateTempId();
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
            return resolve(body);
          } catch (err) {
            return reject(err)
          }
        }
        return reject(error)
      });
    })
  }
}

export default new IdentityStore()
