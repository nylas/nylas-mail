import {NylasError, RetryableError} from './errors'

export class IMAPRetryableError extends RetryableError {
  constructor(msg) {
    super(msg)
    this.userMessage = "We were unable to reach your IMAP provider. Please try again.";
    this.statusCode = 408;
  }
}

/**
 * IMAPErrors that originate from NodeIMAP. See `convertImapError` for
 * documentation on underlying causes
 */
export class IMAPSocketError extends IMAPRetryableError { }
export class IMAPConnectionTimeoutError extends IMAPRetryableError { }
export class IMAPAuthenticationTimeoutError extends IMAPRetryableError { }
export class IMAPTransientAuthenticationError extends IMAPRetryableError { }

export class IMAPProtocolError extends NylasError {
  constructor(msg) {
    super(msg)
    this.userMessage = "IMAP protocol error. Please contact support@nylas.com."
    this.statusCode = 401
  }
}
export class IMAPAuthenticationError extends NylasError {
  constructor(msg) {
    super(msg)
    this.userMessage = "Incorrect IMAP username or password.";
    this.statusCode = 401;
  }
}

export class IMAPConnectionNotReadyError extends IMAPRetryableError {
  constructor(funcName) {
    super(`${funcName} - You must call connect() first.`);
  }
}

export class IMAPConnectionEndedError extends IMAPRetryableError {
  constructor(msg = "The IMAP Connection was ended.") {
    super(msg);
  }
}

/**
 * Certificate validation failures may correct themselves over long spans
 * of time, but not over the short spans of time in which it'd make sense
 * for us to retry.
 */
export class IMAPCertificateError extends NylasError {
  constructor(msg, host) {
    super(msg)
    this.userMessage = `Certificate Error: We couldn't verify the identity of the IMAP server "${host}".`
    this.statusCode = 495
  }
}

/**
 * IMAPErrors may come from:
 *
 * 1. Underlying IMAP provider (Fastmail, Yahoo, etc)
 * 2. Node IMAP
 * 3. K2 code
 *
 * NodeIMAP puts a `source` attribute on `Error` objects to indicate where
 * a particular error came from. See https://github.com/mscdex/node-imap/blob/master/lib/Connection.js
 *
 * These may have the following values:
 *
 *   - "socket-timeout": Created by NodeIMAP when `config.socketTimeout`
 *     expires on the base Node `net.Socket` and socket.on('timeout') fires
 *     Message: 'Socket timed out while talking to server'
 *
 *   - "timeout": Created by NodeIMAP when `config.connTimeout` has been
 *     reached when trying to connect the socket.
 *     Message: 'Timed out while connecting to server'
 *
 *   - "socket": Created by Node's `net.Socket` on error. See:
 *     https://nodejs.org/api/net.html#net_event_error_1
 *     Message: Various from `net.Socket`
 *
 *   - "protocol": Created by NodeIMAP when `bad` or `no` types come back
 *     from the IMAP protocol.
 *     Message: Various from underlying IMAP protocol
 *
 *   - "authentication": Created by underlying IMAP connection or NodeIMAP
 *     in a few scenarios.
 *     Message: Various from underlying IMAP connection
 *              OR: No supported authentication method(s) available. Unable to login.
 *              OR: Logging in is disabled on this server
 *
 *   - "timeout-auth": Created by NodeIMAP when `config.authTimeout` has
 *     been reached when trying to authenticate
 *     Message: 'Timed out while authenticating with server'
 *
 */
export function convertImapError(imapError, {connectionSettings} = {}) {
  let error = imapError;

  if (/try again/i.test(imapError.message)) {
    error = new RetryableError(imapError)
    error.source = imapError.source
    return error
  }
  if (/system error/i.test(imapError.message)) {
    // System Errors encountered in the wild so far have been retryable.
    error = new RetryableError(imapError)
    error.source = imapError.source
    return error
  }
  if (/user is authenticated but not connected/i.test(imapError.message)) {
    // We need to treat this type of error as retryable
    // See https://github.com/mscdex/node-imap/issues/523 for more details
    error = new RetryableError(imapError)
    error.source = imapError.source
    return error
  }
  if (/server unavailable/i.test(imapError.message)) {
    // Server Unavailable encountered in the wild so far have been retryable.
    error = new RetryableError(imapError)
    error.source = imapError.source
    return error
  }

  switch (imapError.source) {
    case "socket-timeout":
      error = new IMAPConnectionTimeoutError(imapError); break;
    case "timeout":
      error = new IMAPConnectionTimeoutError(imapError); break;
    case "socket":
      if (imapError.code === "UNABLE_TO_VERIFY_LEAF_SIGNATURE") {
        error = new IMAPCertificateError(imapError, connectionSettings.host);
      } else if (imapError.code === "SELF_SIGNED_CERT_IN_CHAIN") {
        error = new IMAPCertificateError(imapError, connectionSettings.host);
      } else {
        error = new IMAPSocketError(imapError);
      }
      break;
    case "protocol":
      error = new IMAPProtocolError(imapError); break;
    case "authentication":
      error = new IMAPAuthenticationError(imapError); break;
    case "timeout-auth":
      error = new IMAPAuthenticationTimeoutError(imapError); break;
    default:
      break;
  }
  error.source = imapError.source
  return error
}
