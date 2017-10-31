/* eslint global-require: 0 */
import { APIError } from './errors';

// A 0 code is when an error returns without a status code, like "ESOCKETTIMEDOUT"
export const TimeoutErrorCodes = [
  0,
  408,
  'ETIMEDOUT',
  'ESOCKETTIMEDOUT',
  'ECONNRESET',
  'ENETDOWN',
  'ENETUNREACH',
];
export const PermanentErrorCodes = [
  400,
  401,
  402,
  403,
  404,
  405,
  429,
  500,
  'ENOTFOUND',
  'ECONNREFUSED',
  'EHOSTDOWN',
  'EHOSTUNREACH',
];
export const CanceledErrorCodes = [-123, 'ECONNABORTED'];
export const SampleTemporaryErrorCode = 504;

let IdentityStore = null;

// server option

export function rootURLForServer(server) {
  const env = AppEnv.config.get('env');

  if (!['development', 'staging', 'production'].includes(env)) {
    throw new Error(`rootURLForServer: ${env} is not a valid environment.`);
  }

  if (server === 'identity') {
    return {
      development: 'http://localhost:5101',
      staging: 'https://id-staging.getmailspring.com',
      production: 'https://id.getmailspring.com',
    }[env];
  }
  throw new Error('rootURLForServer: You must provide a valid `server` value');
}

export async function makeRequest(options) {
  // for some reason when `fetch` completes, the stack trace has been lost.
  // In case the request failsm capture the stack now.
  const root = rootURLForServer(options.server);

  options.headers = options.headers || new Headers();
  options.headers.set('Accept', 'application/json');
  options.credentials = 'include';

  if (!options.auth && options.auth !== false) {
    if (options.server === 'identity') {
      IdentityStore = IdentityStore || require('./stores/identity-store').default;
      const username = IdentityStore.identity().token;
      options.headers.set('Authorization', `Basic ${btoa(`${username}:`)}`);
    }
  }

  if (options.path) {
    options.url = `${root}${options.path}`;
  }

  if (options.body && !(options.body instanceof FormData)) {
    options.headers.set('Content-Type', 'application/json');
    options.body = JSON.stringify(options.body);
  }

  const error = new APIError(`${options.method || 'GET'} ${options.url} failed`);
  let resp = null;
  try {
    resp = await fetch(options.url, options);
  } catch (uselessFetchError) {
    throw error;
  }
  if (!resp.ok) {
    error.statusCode = resp.status;
    error.message = `${options.method ||
      'GET'} ${options.url} returned ${resp.status} ${resp.statusText}`;
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
};
