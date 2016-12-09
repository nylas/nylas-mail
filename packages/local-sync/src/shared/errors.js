class HTTPError extends Error {
  constructor(message, httpCode, logContext) {
    super(message);
    this.httpCode = httpCode;
    this.logContext = logContext;
  }
}

module.exports = {
  HTTPError,
}
