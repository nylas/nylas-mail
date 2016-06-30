const SyncbackTask = require('./syncback-task')

class DeleteFolderIMAP extends SyncbackTask {
  description() {
    return `DeleteFolder`;
  }

  run(db, imap) {
    const folderId = this.syncbackRequestObject().props.id
    return db.Folder.findById(folderId).then((folder) => {
      return imap.delBox(folder.name);
    })
  }
}
module.exports = DeleteFolderIMAP
