class MoveToFolderIMAP {
  constructor(account, syncbackRequest) {
    this._account = account;
    this._syncbackRequest = syncbackRequest;
  }

  description() {
    return `MoveToFolder`;
  }

  run(db, imap) {
    console.log("RUNNING MOVE TO FOLDER IMAP");
    return Promise.resolve();
  }
}
module.exports = MoveToFolderIMAP
