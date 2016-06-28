class MoveToFolderIMAP {
  constructor(account, syncbackRequest) {
    this._account = account;
    this._syncbackRequest = syncbackRequest;
  }

  description() {
    return `MoveToFolder`;
  }

  run(db, imap) {
  }
}
module.exports = MoveToFolderIMAP
