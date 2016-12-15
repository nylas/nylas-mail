
class APIError extends Error {
  constructor(message, statusCode, data) {
    super(message);
    this.statusCode = statusCode;
    this.data = data;
  }

  toJSON() {
    const json = super.toJSON() || {}
    Object.getOwnPropertyNames(this).forEach((key) => {
      json[key] = this[key];
    });
    return json
  }
}

module.exports = {
  APIError,
}
