class SyncbackTask {
  constructor(account, syncbackRequest) {
    this._account = account;
    this._syncbackRequest = syncbackRequest;
    if (!this._account) {
      throw new Error("SyncbackTask requires an account")
    }
    if (!this._syncbackRequest) {
      throw new Error("SyncbackTask requires a syncbackRequest")
    }
    this._logger = global.Logger.forAccount(this._account)
  }

  syncbackRequestObject() {
    return this._syncbackRequest;
  }

  description() {
    throw new Error("Must return a description")
  }

  affectsImapMessageUIDs() {
    throw new Error("Must implement `affectsImapMessageUIDs`")
  }

  run() {
    throw new Error("Must implement a run method")
  }
}
module.exports = SyncbackTask
