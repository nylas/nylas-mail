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
        return db.Category.findById(toFolderId).then((newCategory) => {
          return box.moveFromBox(message.categoryImapUID, newCategory.name)
        })
      })
  }
}
module.exports = MoveMessageToFolderIMAP
