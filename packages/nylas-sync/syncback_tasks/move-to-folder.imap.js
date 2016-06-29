class MoveToFolderIMAP {
  constructor(account, syncbackRequest) {
    this._account = account;
    this._syncbackRequest = syncbackRequest;
  }

  syncbackRequestObject() {
    return this._syncbackRequest;
  }

  description() {
    return `MoveToFolder`;
  }

  run(db, imap) {
    console.log("----------------------- RUNNING MOVE TO FOLDER IMAP");
    imap.getBoxes().then(console.log)
    return Promise.resolve();
  }
}
module.exports = MoveToFolderIMAP
