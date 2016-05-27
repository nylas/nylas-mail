import request from 'request'
import Utils from './models/utils'
import Actions from './actions'
import {APIError} from './errors'
import PriorityUICoordinator from '../priority-ui-coordinator'
import IdentityStore from './stores/identity-store'
import NylasAPI from './nylas-api'

export default class NylasAPIRequest {
  constructor(api, options) {
    const defaults = {
      url: `${api.APIRoot}${options.path}`,
      method: 'GET',
      json: true,
      timeout: 15000,
      started: () => {},
      error: () => {},
      success: () => {},
    }

    this.api = api;
    this.options = Object.assign(defaults, options);
    if (this.options.method !== 'GET' || this.options.formData) {
      this.options.body = this.options.body || {};
    }
  }

  constructAuthHeader() {
    if (!this.options.accountId) {
      throw new Error("Cannot make Nylas request without specifying `auth` or an `accountId`.");
    }

    const identity = IdentityStore.identity();
    if (identity && !identity.token) {
      throw new Error("Identity is present but identity token is missing.");
    }

    const accountToken = this.api.accessTokenForAccountId(this.options.accountId);
    if (!accountToken) {
      throw new Error(`Cannot make Nylas request for account ${this.options.accountId} auth token.`);
    }

    return {
      user: accountToken,
      pass: identity ? identity.token : '',
      sendImmediately: true,
    };
  }

  run() {
    if (!this.options.auth) {
      try {
        this.options.auth = this.constructAuthHeader();
      } catch (err) {
        return Promise.reject(new APIError({body: err.message, statusCode: 400}));
      }
    }

    const requestId = Utils.generateTempId();

    return new Promise((resolve, reject) => {
      this.options.startTime = Date.now();
      Actions.willMakeAPIRequest({
        request: this.options,
        requestId: requestId,
      });

      const req = request(this.options, (error, response = {}, body) => {
        Actions.didMakeAPIRequest({
          request: this.options,
          statusCode: response.statusCode,
          error: error,
          requestId: requestId,
        });

        PriorityUICoordinator.settle.then(() => {
          if (error || (response.statusCode > 299)) {
            // Some errors (like socket errors and some types of offline
            // errors) return with a valid `error` object but no `response`
            // object (and therefore no `statusCode`. To normalize all of
            // this, we inject our own offline status code so people down
            // the line can have a more consistent interface.
            if (!response.statusCode) {
              response.statusCode = NylasAPI.TimeoutErrorCodes[0];
            }
            const apiError = new APIError({error, response, body, requestOptions: this.options});
            NylasEnv.errorLogger.apiDebug(apiError);
            this.options.error(apiError);
            reject(apiError);
          } else {
            this.options.success(body, response);
            resolve(body);
          }
        });
      });

      req.on('abort', () => {
        const cancelled = new APIError({
          statusCode: NylasAPI.CancelledErrorCode,
          body: 'Request Aborted',
        });
        reject(cancelled);
      });

      this.options.started(req);
    });
  }
}
