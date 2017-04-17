export class NylasError extends Error {
  toJSON() {
    let json = {}
    if (super.toJSON) {
      // Chromium `Error`s have a `toJSON`, but Node `Error`s do NOT!
      json = super.toJSON()
    }
    Object.getOwnPropertyNames(this).forEach((key) => {
      json[key] = this[key];
    });
    return json
  }
}

export class APIError extends NylasError {
  constructor(message, statusCode, data) {
    super(message);
    this.statusCode = statusCode;
    this.data = data;
  }
}

/**
 * An abstract base class that can be used to indicate Errors that may fix
 * themselves when retried
 */
export class RetryableError extends NylasError { }
