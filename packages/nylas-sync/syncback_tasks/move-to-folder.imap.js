const SyncbackTask = require('./syncback-task')

class MoveToFolderIMAP extends SyncbackTask {
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
