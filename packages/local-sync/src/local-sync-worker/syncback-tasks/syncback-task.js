class SyncbackTask {
  constructor(account, syncbackRequest) {
    this._account = account;
    this._syncbackRequest = syncbackRequest;
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
