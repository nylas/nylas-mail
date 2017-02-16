import NylasStore from 'nylas-store'
import {DatabaseStore} from 'nylas-exports'
import SalesforceAPI from './salesforce-api'
import SalesforceOAuth from './salesforce-oauth'
import SalesforceObject from './models/salesforce-object'
import SalesforceActions from './salesforce-actions'
import SalesforceDataReset from './salesforce-data-reset'

// const loggedInMenu = require('../menus/salesforce-logged-in.json');
// const loggedOutMenu = require('../menus/salesforce-logged-out.json');

/**
 * The Salesforce environment. Requires config to be populated from an
 * Oauth request with the following information:
 *
 * Note we store the access_token and refresh_token in the system keychain
 *
 * "salesforce": {
 *   "instance_url": "",
 *   "id": ""
 * },
 *
 */
class SalesforceEnv extends NylasStore {
  constructor() {
    super()
    this._menuListeners = []
    this._subs = []
    this._lastIdentityUrl = this._getIdentityUrl()
  }

  activate() {
    if (NylasEnv.isMainWindow()) {
      SalesforceOAuth.activate()
      this.listenTo(SalesforceActions.loginToSalesforce, this._login)
      this.listenTo(SalesforceActions.logoutOfSalesforce, this._logout)
    }

    this._subs.push(NylasEnv.config.onDidChange('salesforce.id', this._onIdentityChange));
    this._listenForLoginState()
    this._onIdentityChange()
  }

  deactivate() {
    for (const sub of this._subs) { sub.dispose() }
    for (const sub of this._menuListeners) { sub.dispose() }
    this.stopListeningToAll();
    if (NylasEnv.isMainWindow()) {
      SalesforceOAuth.deactivate()
    }
  }

  isLoggedIn() {
    return this._getIdentityUrl() && this._getIdentityUrl().length > 0
  }

  // menuForLoginState() {
  //   return this.isLoggedIn() ? loggedInMenu : loggedOutMenu
  // }

  _listenForLoginState() {
    for (const sub of this._menuListeners) { sub.dispose() }

    this._menuListeners = [
      NylasEnv.commands.add(document.body, "salesforce:sync", () => SalesforceActions.syncSalesforce()),
    ]
    if (this.isLoggedIn()) {
      this._menuListeners.push(NylasEnv.commands.add(document.body, "salesforce:disconnect", this._logout));
    } else {
      this._menuListeners.push(NylasEnv.commands.add(document.body, "salesforce:connect", this._login));
    }
  }

  instanceUrl() {
    return NylasEnv.config.get("salesforce.instance_url")
  }

  loadIdentity() {
    const idUrl = this._getIdentityUrl();
    if (!idUrl) return Promise.resolve(null);

    return DatabaseStore.findBy(SalesforceObject, {
      identifier: idUrl,
    }).then((identity) => {
      if (!identity) {
        return this._fetchIdentityFromAPI().then(this._saveIdentity)
      }
      return identity
    })
  }

  _getIdentityUrl() {
    return NylasEnv.config.get("salesforce.id")
  }

  _onIdentityChange = () => {
    if (this._lastIdentityUrl !== this._getIdentityUrl()) {
      this._lastIdentityUrl = this._getIdentityUrl()
      this._listenForLoginState();
    }
    this.trigger()
  }

  _fetchIdentityFromAPI = () => {
    const idUrl = this._getIdentityUrl();
    if (!idUrl) return Promise.resolve(null);
    return SalesforceAPI.makeRequest({
      APIRoot: idUrl,
      path: "/",
    })
  }

  _saveIdentity = (identityJSON) => {
    if (!identityJSON) {
      SalesforceActions.reportError(new Error("Could not load Identity"), {
        APIRoot: this._getIdentityUrl(),
      });
      return {};
    }

    const user = new SalesforceObject({
      id: identityJSON.user_id,
      type: "User",
      name: identityJSON.display_name,
      identifier: this._getIdentityUrl(),
      object: "SalesforceObject",
      rawData: identityJSON,
    })
    return DatabaseStore.inTransaction(t => t.persistModel(user))
    .then(() => user)
  }

  _login = () => {
    SalesforceOAuth.connect()
  }

  _logout = () => {
    return SalesforceDataReset.deleteAllData()
    .then(() => {
      NylasEnv.config.set("salesforce", {});
      SalesforceOAuth.clearTokens()
    });
  }
}

export default new SalesforceEnv()
