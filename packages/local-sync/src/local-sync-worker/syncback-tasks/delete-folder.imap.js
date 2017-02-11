const {SyncbackIMAPTask} = require('./syncback-task')

class DeleteFolderIMAP extends SyncbackIMAPTask {
  description() {
    return `DeleteFolder`;
  }

  affectsImapMessageUIDs() {
    return true
  }

  async run(db, imap) {
    const {folderId} = this.syncbackRequestObject().props
    const folder = await db.Folder.findById(folderId)
    if (!folder) {
      // Nothing to delete!
      return
    }
    await imap.delBox(folder.name);

    // If IMAP succeeds, save updates to the db
    await folder.destroy()
  }
}
module.exports = DeleteFolderIMAP
