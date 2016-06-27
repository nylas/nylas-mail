class NylasError extends Error {
  constructor(message) {
    super(message);
    this.name = this.constructor.name;
    this.message = message;
    Error.captureStackTrace(this, this.constructor);
  }

  toJSON() {
    const obj = {}
    Object.getOwnPropertyNames(this).forEach((key) => {
      obj[key] = this[key];
    });
    return obj
  }
}

module.exports = NylasError
