const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class MoveMessageToFolderIMAP extends SyncbackTask {
  description() {
    return `MoveMessageToFolder`;
  }

  async run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId
    const targetFolderId = this.syncbackRequestObject().props.folderId

    const {box, message} = await TaskHelpers.openMessageBox({messageId, db, imap})
    return TaskHelpers.moveMessageToFolder({db, box, message, targetFolderId})
  }
}
module.exports = MoveMessageToFolderIMAP
