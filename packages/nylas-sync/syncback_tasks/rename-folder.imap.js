const SyncbackTask = require('./syncback-task')

class RenameFolderIMAP extends SyncbackTask {
  description() {
    return `RenameFolder`;
  }

  run(db, imap) {
    const folderId = this.syncbackRequestObject().props.id
    const newFolderName = this.syncbackRequestObject().props.displayName
    return db.Folder.findById(folderId).then((folder) => {
      return imap.renameBox(folder.name, newFolderName);
    })
  }
}
module.exports = RenameFolderIMAP
