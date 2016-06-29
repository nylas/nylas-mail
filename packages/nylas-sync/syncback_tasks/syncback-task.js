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

  run() {
    throw new Error("Must implement a run method")
  }
}
module.exports = SyncbackTask
