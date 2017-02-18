/* eslint global-require: 0 */

import fs from 'fs'
import request from 'request'
import crypto from 'crypto'
import {remote} from 'electron'
import Utils from './models/utils'
import Actions from './actions'
import {APIError, RequestEnsureOnceError} from './errors'
import PriorityUICoordinator from '../priority-ui-coordinator'
import IdentityStore from './stores/identity-store'

export default class NylasAPIRequest {
  constructor({api, options}) {
    const defaults = {
      url: `${options.APIRoot || api.APIRoot}${options.path}`,
      method: 'GET',
      json: true,
      timeout: 15000,
      ensureOnce: false,
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

  constructAuthHeader() {
    if (!this.options.accountId) {
      throw new Error("Cannot make Nylas request without specifying `auth` or an `accountId`.");
    }

    const identity = IdentityStore.identity();
    if (identity && !identity.token) {
      const clickedIndex = remote.dialog.showMessageBox({
        type: 'error',
        message: 'Identity is present but identity token is missing.',
        detail: `Actions like sending and receiving mail require this token. Please log back into your Nylas ID to restore it—your email accounts will not be removed in this process.`,
        buttons: ['Log out'],
      })
      if (clickedIndex === 0) {
        Actions.logoutNylasIdentity()
      }
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

  getRequestHash() {
    const {url, method, requestId, body, qs} = this.options
    const query = qs ? qs.toJSON() : ''
    const md5sum = crypto.createHash('md5')
    const data = `${requestId || ''}${method}${url}${query}${body || ''}`
    md5sum.update(data)
    return md5sum.digest('hex')
  }

  requestHasSucceededBefore() {
    const hash = this.getRequestHash()
    return fs.existsSync(`${NylasEnv.getConfigDirPath()}/${hash}`)
  }

  writeRequestSuccessRecord() {
    try {
      const hash = this.getRequestHash()
      fs.writeFileSync(`${NylasEnv.getConfigDirPath()}/${hash}`)
    } catch (e) {
      console.warn('NylasAPIRequest: Error writing request success record to filesystem')
    }
  }

  run() {
    const NylasAPI = require("./nylas-api").default
    const NylasAPIHelpers = require("./nylas-api-helpers")

    if (NylasEnv.getLoadSettings().isSpec) {
      return Promise.resolve([])
    }

    if (this.options.ensureOnce === true) {
      try {
        if (this.requestHasSucceededBefore()) {
          const error = new RequestEnsureOnceError('NylasAPIRequest: request with `ensureOnce = true` has already succeeded before. This commonly happens when the worker window reboots before send has completed.')
          return Promise.reject(error)
        }
      } catch (error) {
        return Promise.reject(error)
      }
    }
    if (!this.options.auth) {
      try {
        this.options.auth = this.constructAuthHeader();
      } catch (err) {
        return Promise.reject(new APIError({body: err.message, statusCode: 400}));
      }
    }

    const requestId = Utils.generateTempId();

    const onSuccess = (body) => {
      let responseBody = body;
      if (this.options.beforeProcessing) {
        responseBody = this.options.beforeProcessing(responseBody)
      }
      if (this.options.returnsModel) {
        NylasAPIHelpers.handleModelResponse(responseBody).then(() => {
          return Promise.resolve(responseBody)
        })
      }
      return Promise.resolve(responseBody)
    }

    const onError = (err) => {
      const {url, auth, returnsModel} = this.options

      let handlePromise = Promise.resolve()
      if (err.response) {
        if (err.response.statusCode === 404 && returnsModel) {
          handlePromise = NylasAPIHelpers.handleModel404(url)
        }

        // If we got a 401 or 403 from our local sync engine, mark the account
        // as having auth issues.
        if ([401, 403].includes(err.response.statusCode) && url.startsWith(NylasAPI.APIRoot)) {
          const apiName = this.api.constructor.name
          handlePromise = NylasAPIHelpers.handleAuthenticationFailure(url, auth.user, apiName)
        }
        if (err.response.statusCode === 400) {
          NylasEnv.reportError(err)
        }
      }
      return handlePromise.finally(() => Promise.reject(err))
    }

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
            const msg = (error || {}).message || `Unknown Error: ${error}`
            const fingerprint = ["{{ default }}", "local api", response.statusCode, msg];
            NylasEnv.reportError(apiError, {fingerprint: fingerprint});
            reject(apiError);
          } else {
            if (this.options.ensureOnce === true) {
              this.writeRequestSuccessRecord()
            }
            this.response = response
            resolve(body);
          }
        });
      });

      req.on('abort', () => {
        const canceled = new APIError({
          statusCode: NylasAPI.CanceledErrorCode,
          body: 'Request Aborted',
        });
        reject(canceled);
      });

      this.options.started(req);
    })
    .then(onSuccess, onError)
  }
}
