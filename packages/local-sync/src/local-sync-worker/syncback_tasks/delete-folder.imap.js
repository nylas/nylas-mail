const SyncbackTask = require('./syncback-task')

class DeleteFolderIMAP extends SyncbackTask {
  description() {
    return `DeleteFolder`;
  }

  affectsImapMessageUIDs() {
    return true
  }

  async run(db, imap) {
    const folderId = this.syncbackRequestObject().props.folderId
    const folder = await db.Folder.findById(folderId)
    if (!folder) {
      // Nothing to delete!
      return null;
    }
    return imap.delBox(folder.name);
  }
}
module.exports = DeleteFolderIMAP
