const {SyncbackIMAPTask} = require('./syncback-task')

class DeleteFolderIMAP extends SyncbackIMAPTask {
  description() {
    return `DeleteFolder`;
  }

  affectsImapMessageUIDs() {
    return true
  }

  async * _run(db, imap) {
    const {folderId} = this.syncbackRequestObject().props
    const folder = yield db.Folder.findById(folderId)
    if (!folder) {
      // Nothing to delete!
      return
    }
    yield imap.delBox(folder.name);

    // If IMAP succeeds, save updates to the db
    yield folder.destroy()
  }
}
module.exports = DeleteFolderIMAP
