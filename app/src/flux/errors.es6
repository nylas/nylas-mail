// This file contains custom Nylas error classes.
//
// In general I think these should be created as sparingly as possible.
// Only add one if you really can't use native `new Error("my msg")`


// A wrapper around the three arguments we get back from node's `request`
// method. We wrap it in an error object because Promises can only call
// `reject` or `resolve` with one argument (not three).
export class APIError extends Error {

  static NonReportableStatusCodes = [
    0,   // When errors like ETIMEDOUT, ECONNABORTED or ESOCKETTIMEDOUT occur from the client
    401, // Don't report `Incorrect username or password`
    404, // Don't report not-founds
    408, // Timeout error code
    429, // Too many requests
  ]

  constructor({error, message, response, body, requestOptions, statusCode} = {}) {
    super();

    this.name = "APIError";
    this.error = error;
    this.body = body;
    this.requestOptions = requestOptions;
    this.statusCode = statusCode;
    this.message = message;

    if (this.statusCode == null) {
      if (response && response.statusCode != null) {
        this.statusCode = response.statusCode
      }

      if (error) {
        // If the server returns anything (including 500s and other bad
        // responses, the `error` object for the `request` will be null)
        //
        // The Node `request` library emits a special type of timeout
        // error for ESOCKETTIMEDOUT and ETIMEDOUT. When it does this it
        // sets the `code` param on the error object. These errors are
        // retryable and we use out special `0` status code.
        //
        // It may also emit normal `Error` objects for other unforseen
        // issues. In this case we set a `500` status code.
        if (error.code) {
          this.statusCode = 0;
        } else {
          this.statusCode = 500;
        }
      }
    }
    if (this.requestOptions == null) {
      this.requestOptions = response ? response.requestOptions : null;
    }

    this.stack = (new Error()).stack;
    if (!this.message) {
      if (this.body) {
        this.message = this.body.message || this.body.error || JSON.stringify(this.body)
      } else {
        this.message = this.error ? this.error.message || this.error.toString() : null;
      }
    }
    this.errorType = (this.body ? this.body.type : null);
  }

  shouldReportError() {
    return !APIError.NonReportableStatusCodes.includes(this.statusCode)
  }

  fromJSON(json = {}) {
    for (const key of Object.keys(json)) {
      this[key] = json[key];
    }
    return this;
  }
}

export class RequestEnsureOnceError extends Error {

}
