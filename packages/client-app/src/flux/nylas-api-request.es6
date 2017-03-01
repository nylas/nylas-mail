import request from 'request'
import {remote} from 'electron'

import Utils from './models/utils'
import Actions from './actions'
import {APIError} from './errors'
import IdentityStore from './stores/identity-store'

export default class NylasAPIRequest {
  constructor({api, options}) {
    const defaults = {
      url: `${options.APIRoot || api.APIRoot}${options.path}`,
      method: 'GET',
      json: true,
      timeout: 30000,
      started: () => {},
    }

    this.api = api;
    this.options = Object.assign(defaults, options);
    this.response = null

    const bodyIsRequired = (this.options.method !== 'GET' && !this.options.formData);
    if (bodyIsRequired) {
      const fallback = this.options.json ? {} : '';
      this.options.body = this.options.body || fallback;
    }
  }

  async run() {
    if (NylasEnv.getLoadSettings().isSpec) return Promise.resolve([]);
    try {
      this.options.auth = this.options.auth || this._defaultAuth();
      return await this._asyncRequest(this.options)
    } catch (error) {
      let apiError = error
      if (!(apiError instanceof APIError)) {
        apiError = new APIError({error: apiError, statusCode: 500})
      }
      this._notifyOfAPIError(apiError)
      throw apiError
    }
  }

  /**
   * An async wrapper around `request`. We reject on any non 2xx codes or
   * other errors.
   *
   * Resolves to the JSON body or rejects with an APIError object.
   */
  async _asyncRequest(options = {}) {
    return new Promise((resolve, reject) => {
      const requestId = Utils.generateTempId();
      const reqTrackingArgs = {request: options, requestId}
      Actions.willMakeAPIRequest(reqTrackingArgs);
      const req = request(options, (error, response, body) => {
        this.response = response;
        let statusCode = (response || {}).statusCode;

        if (statusCode >= 200 && statusCode <= 299) {
          Actions.didMakeAPIRequest({statusCode, ...reqTrackingArgs});
          return resolve(body)
        }

        if (error) {
          // If the server returns anything (including 500s and other bad
          // responses, the `error` object for the `request` will be null)
          //
          // The Node `request` library emits a special type of timeout
          // error for ESOCKETTIMEDOUT and ETIMEDOUT. When it does this it
          // sets the `cod` param on the error object. These errors are
          // retryable and we use out special `0` status code.
          //
          // It may also emit normal `Error` objects for other unforseen
          // issues. In this case we set a `500` status code.
          if (error.code) {
            statusCode = 0;
          } else {
            statusCode = 500;
          }
        }
        const apiError = new APIError({
          body: body,
          error: error,
          response: response,
          statusCode: statusCode,
          requestOptions: options,
        });
        Actions.didMakeAPIRequest({...reqTrackingArgs, statusCode, error: apiError});
        return reject(apiError)
      });
      options.started(req);
    })
  }


  async _notifyOfAPIError(apiError) {
    const ignorableStatusCodes = [
      0,   // Local issues like ETIMEDOUT or ESOCKETTIMEDOUT
      404, // Don't report not-founds
      408, // Timeout error code
      429, // Too many requests
    ]
    if (!ignorableStatusCodes.includes(apiError.statusCode)) {
      const msg = apiError.message || `Unknown Error: ${apiError}`
      const fingerprint = ["{{ default }}", "local api", apiError.statusCode, msg];
      NylasEnv.reportError(apiError, {fingerprint: fingerprint});
      apiError.reported = true
    }

    if ([401, 403].includes(apiError.statusCode)) {
      Actions.apiAuthError(apiError, this.options, this.api.constructor.name)
    }
  }

  /**
   * Generates the basic auth username from the account token and the
   * basic auth password from the NylasID token.
   *
   * This asserts if any of these pieces are missing and throws an
   * APIError object.
   */
  _defaultAuth() {
    try {
      if (!this.options.accountId) {
        throw new Error("Cannot make Nylas request without specifying `auth` or an `accountId`.");
      }

      const identity = IdentityStore.identity();

      if (!identity || !identity.token) {
        const clickedIndex = remote.dialog.showMessageBox({
          type: 'error',
          message: 'Your NylasID is invalid. Please log out then log back in.',
          detail: `Actions like sending and receiving mail require this token. Please log back into your Nylas ID to restore it—your email accounts will not be removed in this process.`,
          buttons: ['Log out'],
        })
        if (clickedIndex === 0) {
          Actions.logoutNylasIdentity()
        }
        throw new Error("No Identity")
      }

      const accountToken = this.api.accessTokenForAccountId(this.options.accountId);
      if (!accountToken) {
        throw new Error(`Auth token missing for account`);
      }

      return {
        user: accountToken,
        pass: identity.token,
        sendImmediately: true,
      };
    } catch (error) {
      throw new APIError({error, statusCode: 400});
    }
  }
}
