const SyncbackTask = require('./syncback-task')

class CreateFolderIMAP extends SyncbackTask {
  description() {
    return `CreateFolder`;
  }

  run(db, imap) {
    const folderName = this.syncbackRequestObject().props.displayName
    return imap.addBox(folderName)
  }
}
module.exports = CreateFolderIMAP
