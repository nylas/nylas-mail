import AccountStore from './stores/account-store'

// A 0 code is when an error returns without a status code, like "ESOCKETTIMEDOUT"
const TimeoutErrorCodes = [0, 408, "ETIMEDOUT", "ESOCKETTIMEDOUT", "ECONNRESET", "ENETDOWN", "ENETUNREACH"]
const PermanentErrorCodes = [400, 401, 402, 403, 404, 405, 429, 500, "ENOTFOUND", "ECONNREFUSED", "EHOSTDOWN", "EHOSTUNREACH"]
const CanceledErrorCodes = [-123, "ECONNABORTED"]
const SampleTemporaryErrorCode = 504


class NylasAPI {

  constructor() {
    let port = 2578;
    if (NylasEnv.inDevMode()) port = 1337;
    this.APIRoot = `http://localhost:${port}`

    this.TimeoutErrorCodes = TimeoutErrorCodes
    this.PermanentErrorCodes = PermanentErrorCodes
    this.CanceledErrorCodes = CanceledErrorCodes
    this.SampleTemporaryErrorCode = SampleTemporaryErrorCode
  }

  accessTokenForAccountId(aid) {
    return AccountStore.tokensForAccountId(aid).localSync
  }
}

export default new NylasAPI()
