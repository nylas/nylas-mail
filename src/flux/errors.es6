// This file contains custom Nylas error classes.
//
// In general I think these should be created as sparingly as possible.
// Only add one if you really can't use native `new Error("my msg")`


// A wrapper around the three arguments we get back from node's `request`
// method. We wrap it in an error object because Promises can only call
// `reject` or `resolve` with one argument (not three).
export class APIError extends Error {
  constructor({error, message, response, body, requestOptions, statusCode} = {}) {
    super();

    this.name = "APIError";
    this.error = error;
    this.response = response;
    this.body = body;
    this.requestOptions = requestOptions;
    this.statusCode = statusCode;
    this.message = message;

    if (this.statusCode == null) {
      this.statusCode = this.response ? this.response.statusCode : null;
    }
    if (this.requestOptions == null) {
      this.requestOptions = this.response ? this.response.requestOptions : null;
    }

    this.stack = (new Error()).stack;
    if (!this.message) {
      this.message = (this.body ? this.body.message : null) || this.body || (this.error ? this.error.toString() : null);
    }
    this.errorType = (this.body ? this.body.type : null);
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
