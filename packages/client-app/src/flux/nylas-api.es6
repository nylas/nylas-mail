import {AccountStore} from 'nylas-exports'
import NylasLongConnection from './nylas-long-connection'

// A 0 code is when an error returns without a status code, like "ESOCKETTIMEDOUT"
const TimeoutErrorCodes = [0, 408, "ETIMEDOUT", "ESOCKETTIMEDOUT", "ECONNRESET", "ENETDOWN", "ENETUNREACH"]
const PermanentErrorCodes = [400, 401, 402, 403, 404, 405, 429, 500, "ENOTFOUND", "ECONNREFUSED", "EHOSTDOWN", "EHOSTUNREACH"]
const CanceledErrorCodes = [-123, "ECONNABORTED"]
const SampleTemporaryErrorCode = 504


class NylasAPIChangeLockTracker {
  constructor() {
    this._locks = {}
  }

  acceptRemoteChangesTo(klass, id) {
    const key = `${klass.name}-${id}`
    return this._locks[key] === undefined
  }

  increment(klass, id) {
    const key = `${klass.name}-${id}`
    this._locks[key] = this._locks[key] || 0
    this._locks[key] += 1
  }

  decrement(klass, id) {
    const key = `${klass.name}-${id}`
    if (!this._locks[key]) return
    this._locks[key] -= 1
    if (this._locks[key] <= 0) {
      delete this._locks[key]
    }
  }

  print() {
    console.log("The following models are locked:")
    console.log(this._locks)
  }
}


class NylasAPI {

  constructor() {
    this.lockTracker = new NylasAPIChangeLockTracker()
    let port = 2578;
    if (NylasEnv.inDevMode()) port = 1337;
    this.APIRoot = `http://localhost:${port}`

    this.TimeoutErrorCodes = TimeoutErrorCodes
    this.PermanentErrorCodes = PermanentErrorCodes
    this.CanceledErrorCodes = CanceledErrorCodes
    this.SampleTemporaryErrorCode = SampleTemporaryErrorCode
    this.LongConnectionStatus = NylasLongConnection.Status
  }

  accessTokenForAccountId(aid) {
    return AccountStore.tokensForAccountId(aid).localSync
  }

  incrementRemoteChangeLock = (klass, id) => {
    this.lockTracker.increment(klass, id)
  }

  decrementRemoteChangeLock = (klass, id) => {
    this.lockTracker.decrement(klass, id)
  }
}

export default new NylasAPI()
