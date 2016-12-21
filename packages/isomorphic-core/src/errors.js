
class NylasError extends Error {
  toJSON() {
    const json = super.toJSON() || {}
    Object.getOwnPropertyNames(this).forEach((key) => {
      json[key] = this[key];
    });
    return json
  }
}

class APIError extends NylasError {
  constructor(message, statusCode, data) {
    super(message);
    this.statusCode = statusCode;
    this.data = data;
  }
}

module.exports = {
  NylasError,
  APIError,
}
