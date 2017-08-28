/* eslint global-require: 0 */
import {APIError} from './errors'

// A 0 code is when an error returns without a status code, like "ESOCKETTIMEDOUT"
export const TimeoutErrorCodes = [0, 408, "ETIMEDOUT", "ESOCKETTIMEDOUT", "ECONNRESET", "ENETDOWN", "ENETUNREACH"]
export const PermanentErrorCodes = [400, 401, 402, 403, 404, 405, 429, 500, "ENOTFOUND", "ECONNREFUSED", "EHOSTDOWN", "EHOSTUNREACH"]
export const CanceledErrorCodes = [-123, "ECONNABORTED"]
export const SampleTemporaryErrorCode = 504

let IdentityStore = null;

// server option

export function rootURLForServer(server) {
  const env = NylasEnv.config.get('env');

  if (!['development', 'staging', 'production'].includes(env)) {
    throw new Error(`rootURLForServer: ${env} is not a valid environment.`);
  }

  if (server === 'identity') {
    return {
      development: "http://localhost:5101",
      staging: "https://id-staging.getmerani.com",
      production: "https://id.getmerani.com",
    }[env];
  }
  if (server === 'accounts') {
    return {
      development: "http://localhost:5100",
      staging: "https://accounts-staging.getmerani.com",
      production: "https://accounts.getmerani.com",
    }[env];
  }

  throw new Error("rootURLForServer: You must provide a valid `server` value");
}

export async function makeRequest(options) {
  // for some reason when `fetch` completes, the stack trace has been lost.
  // In case the request failsm capture the stack now.
  const root = rootURLForServer(options.server);

  options.headers = options.headers || new Headers();
  options.headers.set('Accept', 'application/json');
  options.credentials = 'include';

  if (!options.auth) {
    if (options.server === 'identity') {
      IdentityStore = IdentityStore || require('./stores/identity-store').default;
      const username = IdentityStore.identity().token;
      options.headers.set('Authorization', `Basic ${btoa(`${username}:`)}`)
    }
  }

  if (options.path) {
    options.url = `${root}${options.path}`;
  }

  if (options.body && !(options.body instanceof FormData)) {
    options.headers.set('Content-Type', 'application/json');
    options.body = JSON.stringify(options.body);
  }

  const error = new APIError(`${options.method || "GET"} ${options.url} failed`);
  let resp = null;
  try {
    resp = await fetch(options.url, options);
  } catch (uselessFetchError) {
    throw error;
  }
  if (!resp.ok) {
    error.statusCode = resp.status;
    error.message = `${options.method || "GET"} ${options.url} returned ${resp.status} ${resp.statusText}`;
    throw error;
  }
  return resp.json();
}

export default {
  TimeoutErrorCodes,
  PermanentErrorCodes,
  CanceledErrorCodes,
  SampleTemporaryErrorCode,
  rootURLForServer,
  makeRequest,
}

// export default class NylasAPIRequest {

//   constructor({api, options}) {
//     const defaults = {
//       url: `${options.APIRoot || api.APIRoot}${options.path}`,
//       method: 'GET',
//       json: true,
//       timeout: 30000,
//       started: () => {},
//     }

//     this.api = api;
//     this.options = Object.assign(defaults, options);
//     this.response = null

//     const bodyIsRequired = (this.options.method !== 'GET' && !this.options.formData);
//     if (bodyIsRequired) {
//       const fallback = this.options.json ? {} : '';
//       this.options.body = this.options.body || fallback;
//     }
//   }

//   async run() {
//     return null;

//     // TODO BG: Promise.reject();

//     // if (NylasEnv.getLoadSettings().isSpec) return Promise.resolve([]);
//     // try {
//     //   this.options.auth = this.options.auth || this._defaultAuth();
//     //   return await this._asyncRequest(this.options)
//     // } catch (error) {
//     //   let apiError = error
//     //   if (!(apiError instanceof APIError)) {
//     //     apiError = new APIError({error: apiError, statusCode: 500})
//     //   }
//     //   this._notifyOfAPIError(apiError)
//     //   throw apiError
//     // }
//   }

//   /**
//    * An async wrapper around `request`. We reject on any non 2xx codes or
//    * other errors.
//    *
//    * Resolves to the JSON body or rejects with an APIError object.
//    */
//   async _asyncRequest(options = {}) {
//     return new Promise((resolve, reject) => {
//       // Blob requests can potentially contain megabytes of binary data.
//       // it doesn't make sense to send them through the action bridge.
//       const req = request(options, (error, response, body) => {
//         this.response = response;
//         const statusCode = (response || {}).statusCode;

//         if (statusCode >= 200 && statusCode <= 299) {
//           return resolve(body)
//         }

//         const apiError = new APIError({
//           body: body,
//           error: error,
//           response: response,
//           statusCode: statusCode,
//           requestOptions: options,
//         });
//         return reject(apiError)
//       });
//       req.on('abort', () => {
//         // Use a status code of 0 because we don't want to report the error when
//         // we manually abort the request
//         const statusCode = 0
//         const abortedError = new APIError({
//           statusCode,
//           body: 'Request aborted by client',
//         });
//         reject(abortedError);
//       });

//       req.on('aborted', () => {
//         const statusCode = "ECONNABORTED"
//         const abortedError = new APIError({
//           statusCode,
//           body: 'Request aborted by server',
//         });
//         reject(abortedError);
//       });
//       options.started(req);
//     })
//   }


//   async _notifyOfAPIError(apiError) {
//     const {statusCode} = apiError
//     // TODO move this check into NylasEnv.reportError()?
//     if (apiError.shouldReportError()) {
//       const msg = apiError.message || `Unknown Error: ${apiError}`
//       const fingerprint = ["{{ default }}", "api error", this.options.url, apiError.statusCode, msg];
//       NylasEnv.reportError(apiError, {fingerprint,
//         rateLimit: {
//           ratePerHour: 30,
//           key: `APIError:${this.options.url}:${statusCode}:${msg}`,
//         },
//       });
//       apiError.reported = true
//     }

//     if ([401, 403].includes(statusCode)) {
//       Actions.apiAuthError(apiError, this.options, this.api.constructor.name)
//     }
//   }

//   /**
//    * Generates the basic auth username from the account token and the
//    * basic auth password from the NylasID token.
//    *
//    * This asserts if any of these pieces are missing and throws an
//    * APIError object.
//    */
//   _defaultAuth() {
//     try {
//       if (!this.options.accountId) {
//         throw new Error("Cannot make Nylas request without specifying `auth` or an `accountId`.");
//       }

//       const identity = IdentityStore.identity();

//       if (!identity || !identity.token) {
//         // const clickedIndex = remote.dialog.showMessageBox({
//         //   type: 'error',
//         //   message: 'Your NylasID is invalid. Please log out then log back in.',
//         //   detail: `Actions like sending and receiving mail require this token. Please log back into your Nylas ID to restore it—your email accounts will not be removed in this process.`,
//         //   buttons: ['Log out'],
//         // })
//         // if (clickedIndex === 0) {
//         //   Actions.logoutNylasIdentity()
//         // }
//         throw new Error("No Identity")
//       }

//       const accountToken = this.api.accessTokenForAccountId(this.options.accountId);
//       if (!accountToken) {
//         throw new Error(`Auth token missing for account`);
//       }

//       return {
//         user: accountToken,
//         pass: identity.token,
//         sendImmediately: true,
//       };
//     } catch (error) {
//       throw new APIError({error, statusCode: 400});
//     }
//   }
// }
