const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class MoveMessageToFolderIMAP extends SyncbackTask {
  description() {
    return `MoveMessageToFolder`;
  }

  run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId
    const toFolderId = this.syncbackRequestObject().props.folderId

    return TaskHelpers.openMessageBox({messageId, db, imap})
      .then(({box, message}) => {
        return db.Folder.findById(toFolderId).then((newFolder) => {
          return box.moveFromBox(message.folderImapUID, newFolder.name)
        })
      })
  }
}
module.exports = MoveMessageToFolderIMAP
