const SyncbackTask = require('./syncback-task')

class RenameFolderIMAP extends SyncbackTask {
  description() {
    return `RenameFolder`;
  }

  affectsImapMessageUIDs() {
    return true
  }

  async run(db, imap) {
    const folderId = this.syncbackRequestObject().props.folderId
    const newFolderName = this.syncbackRequestObject().props.displayName
    const folder = await db.Folder.findById(folderId)
    return imap.renameBox(folder.name, newFolderName);
  }
}
module.exports = RenameFolderIMAP
