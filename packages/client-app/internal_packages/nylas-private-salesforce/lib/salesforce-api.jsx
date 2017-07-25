import {shell, remote} from 'electron'
import React from 'react'
import {Actions, NylasAPIRequest} from 'nylas-exports'
import SalesforceActions from './salesforce-actions'
import SalesforceOAuth from './salesforce-oauth'
import SalesforceAPIError from './salesforce-api-error'

class SalesforceAPI {
  constructor() {
    this.VERSION = "v37.0"
    NylasEnv.config.onDidChange('salesforce.instance_url', this._setAPIRoot)
    this._setAPIRoot()
    this._apiDisabled = false
    this._tokenRefreshPromise = null
  }

  _setAPIRoot = () => {
    const instanceUrl = NylasEnv.config.get("salesforce.instance_url");
    if (instanceUrl) {
      this.APIRoot = `${instanceUrl}/services/data/${this.VERSION}`;
      this._apiDisabled = false
    } else {
      this.APIRoot = null
    }
  }

  makeRequest(options = {}) {
    if (NylasEnv.getLoadSettings().isSpec) {
      return Promise.resolve();
    }
    if (this._apiDisabled === true) { return Promise.resolve() }
    if (!this.APIRoot) {
      return Promise.reject(new Error("Please authenticate Salesforce first"))
    }

    // Always refresh since the accessToken may have changed.
    options.auth = {
      bearer: SalesforceOAuth.accessToken(),
    }

    const req = new NylasAPIRequest({
      api: this,
      options,
    });

    return req.run()
    .catch((apiError) => {
      const salesforceAPIError = new SalesforceAPIError(apiError)
      if (this._isBadTokenError(salesforceAPIError)) {
        if (!this._tokenRefreshPromise) {
          this._tokenRefreshPromise = this._refreshToken()
        }
        return this._tokenRefreshPromise.then(() => {
          this._tokenRefreshPromise = null;
        }).then(this._retry(options))
      } else if (salesforceAPIError.errorCode === "API_DISABLED_FOR_ORG") {
        Actions.recordUserEvent("Salesforce Connect Errored", {
          errorType: salesforceAPIError.constructor.name,
          errorCode: salesforceAPIError.errorCode,
          errorMessage: salesforceAPIError.message,
        })
        this._handleAPIDisabled()
        return Promise.reject(salesforceAPIError)
      }
      return Promise.reject(salesforceAPIError)
    })
  }

  _retry(options) {
    return () => {
      if (options.retries >= 2) {
        this._unableToAuth()
        return Promise.reject(new Error("Unable to refresh token"))
      }
      options.retries = (options.retries || 0) + 1
      return this.makeRequest(options) // Try one more time
    }
  }

  _isBadTokenError(salesforceAPIError) {
    const statusCode = salesforceAPIError.statusCode
    if (statusCode === 401 || statusCode === 403) {
      if (salesforceAPIError.errorCode === "INVALID_SESSION_ID") return true;
      if (salesforceAPIError.message === "Bad_OAuth_Token") return true;
      SalesforceActions.reportError(salesforceAPIError);
      return false
    }
    return false
  }

  _isLimitExceeded(salesforceAPIError) {
    return (salesforceAPIError.errorCode === "REQUEST_LIMIT_EXCEEDED")
  }

  _handleAPIDisabled() {
    if (this._apiDisabled) return;
    this._apiDisabled = true
    const openLink = () => shell.openExternal("https://help.salesforce.com/HTViewSolution?id=000005140")
    Actions.openModal({
      component: (
        <div className="salesforce-welcome" tabIndex="0">
          <h2>We can&rsquo;t connect to your Salesforce environment</h2>
          <p>Your Salesforce environment does not have API access enabled. If you are using Group or Professional editions, you must either add API access or upgrade to Enterprise edition. If you are already using Enterprise or Ultimate editions please check your installation settings to ensure API access is turned on.</p>
          <p>See <a onClick={openLink}>this Salesforce support article</a> for more information regarding API access.</p>
        </div>
      ),
      height: 290,
      width: 700,
    })
    SalesforceActions.logoutOfSalesforce()
  }

  _unableToAuth() {
    SalesforceActions.logoutOfSalesforce()
    const response = remote.dialog.showMessageBox({
      message: 'Salesforce Connection Problem',
      detail: `We could no longer access your Salesforce environment. Please reconnect Salesforce.`,
      buttons: ['Connect Salesforce', 'Dismiss'],
      type: 'warning',
    });
    if (response === 0) {
      SalesforceActions.loginToSalesforce()
    }
  }

  _refreshToken() {
    return SalesforceOAuth.fetchNewToken()
    .catch((apiError) => {
      this._unableToAuth()
      throw apiError
    })
  }
}

export default new SalesforceAPI()
