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

      // Blob requests can potentially contain megabytes of binary data.
      // it doesn't make sense to send them through the action bridge.
      if (!options.blob) {
        Actions.willMakeAPIRequest(reqTrackingArgs);
      }

      const req = request(options, (error, response, body) => {
        this.response = response;
        const statusCode = (response || {}).statusCode;

        if (statusCode >= 200 && statusCode <= 299) {
          if (!options.blob) {
            Actions.didMakeAPIRequest({statusCode, ...reqTrackingArgs});
          }
          return resolve(body)
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
      req.on('abort', () => {
        // Use a status code of 0 because we don't want to report the error when
        // we manually abort the request
        const statusCode = 0
        const abortedError = new APIError({
          statusCode,
          body: 'Request aborted by client',
        });
        Actions.didMakeAPIRequest({...reqTrackingArgs, statusCode, error: abortedError});
        reject(abortedError);
      });

      req.on('aborted', () => {
        const statusCode = "ECONNABORTED"
        const abortedError = new APIError({
          statusCode,
          body: 'Request aborted by server',
        });
        Actions.didMakeAPIRequest({...reqTrackingArgs, statusCode, error: abortedError});
        reject(abortedError);
      });
      options.started(req);
    })
  }


  async _notifyOfAPIError(apiError) {
    const {statusCode} = apiError
    // TODO move this check into NylasEnv.reportError()?
    if (apiError.shouldReportError()) {
      const msg = apiError.message || `Unknown Error: ${apiError}`
      const fingerprint = ["{{ default }}", "api error", this.options.url, apiError.statusCode, msg];
      NylasEnv.reportError(apiError, {fingerprint,
        rateLimit: {
          ratePerHour: 30,
          key: `APIError:${this.options.url}:${statusCode}:${msg}`,
        },
      });
      apiError.reported = true
    }

    if ([401, 403].includes(statusCode)) {
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
      const accountToken = this.api.accessTokenForAccountId(this.options.accountId);
      if (!accountToken) {
        throw new Error(`Auth token missing for account`);
      }

      return {
        user: accountToken,
        pass: identity && identity.token,
        sendImmediately: true,
      };
    } catch (error) {
      throw new APIError({error, statusCode: 400});
    }
  }
}
