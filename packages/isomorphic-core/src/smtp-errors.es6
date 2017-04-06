import {NylasError, RetryableError} from './errors'

export class SMTPRetryableError extends RetryableError {
  constructor(msg) {
    super(msg)
    this.userMessage = "We were unable to reach your SMTP server. Please try again."
    this.statusCode = 408
  }
}

export class SMTPConnectionTimeoutError extends SMTPRetryableError { }
export class SMTPConnectionEndedError extends SMTPRetryableError { }
export class SMTPConnectionTLSError extends SMTPRetryableError { }

export class SMTPProtocolError extends NylasError {
  constructor(msg) {
    super(msg)
    this.userMessage = "SMTP protocol error. Please check your SMTP settings."
    this.statusCode = 401
  }
}

export class SMTPConnectionDNSError extends NylasError {
  constructor(msg) {
    super(msg)
    this.userMessage = "We were unable to look up your SMTP host. Please check the SMTP server name."
    this.statusCode = 401
  }
}
export class SMTPAuthenticationError extends NylasError {
  constructor(msg) {
    super(msg)
    this.userMessage = "Incorrect SMTP username or password."
    this.statusCode = 401
  }
}

/* Nodemailer's errors are just regular old Error objects, so we have to
 * test the error message to determine more about what they mean
 */
export function convertSmtpError(err) {
  // TODO: what error is thrown if you're offline?
  // TODO: what error is thrown if the message you're sending is too large?
  if (/(?:connection timeout)|(?:connect etimedout)/i.test(err.message)) {
    return new SMTPConnectionTimeoutError(err)
  }
  if (/(?:connection|socket) closed?/i.test(err.message)) {
    const smtpErr = SMTPConnectionEndedError(err)
    if (err.code) {
      // e.g. https://github.com/nodemailer/nodemailer/blob/master/lib/smtp-transport/index.js#L184-L185
      smtpErr.code = err.code;
    }
  }
  if (/error initiating tls/i.test(err.message)) {
    return new SMTPConnectionTLSError(err);
  }
  if (/getaddrinfo enotfound/i.test(err.message)) {
    return new SMTPConnectionDNSError(err);
  }
  if (/unknown protocol/i.test(err.message)) {
    return new SMTPProtocolError(err);
  }
  if (/(?:invalid login)|(?:username and password not accepted)|(?:incorrect username or password)|(?:authentication failed)/i.test(err.message)) {
    return new SMTPAuthenticationError(err);
  }

  return err;
}
