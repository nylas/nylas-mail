const BASE_TIMEOUT = 2 * 1000;
const MAX_TIMEOUT = 5 * 60 * 1000;

function exponentialBackoff(base, numTries) {
  return base * 2 ** numTries;
}

export class BackoffScheduler {
  constructor({ baseDelay, maxDelay, getNextBackoffDelay, jitter = true } = {}) {
    this._numTries = 0;
    this._currentDelay = 0;
    this._jitter = jitter;
    this._maxDelay = maxDelay || MAX_TIMEOUT;
    this._baseDelay = baseDelay || BASE_TIMEOUT;
    if (!getNextBackoffDelay) {
      throw new Error('BackoffScheduler: Must pass `getNextBackoffDelay` function');
    }
    this._getNextBackoffDelay = getNextBackoffDelay;
  }

  numTries() {
    return this._numTries;
  }

  currentDelay() {
    return this._currentDelay;
  }

  reset() {
    this._numTries = 0;
    this._currentDelay = 0;
  }

  nextDelay() {
    const nextDelay = this._calcNextDelay();
    this._numTries++;
    this._currentDelay = nextDelay;
    return nextDelay;
  }

  _calcNextDelay() {
    let nextDelay = this._getNextBackoffDelay(this._baseDelay, this._numTries);
    if (this._jitter) {
      // Why jitter? See:
      // https://www.awsarchitectureblog.com/2015/03/backoff.html
      nextDelay *= Math.random();
    }
    return Math.min(nextDelay, this._maxDelay);
  }
}

export class ExponentialBackoffScheduler extends BackoffScheduler {
  constructor(opts = {}) {
    super({ ...opts, getNextBackoffDelay: exponentialBackoff });
  }
}
