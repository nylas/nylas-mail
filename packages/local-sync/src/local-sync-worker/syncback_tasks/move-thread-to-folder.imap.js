const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class MoveThreadToFolderIMAP extends SyncbackTask {
  description() {
    return `MoveThreadToFolder`;
  }

  run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId
    const toFolderId = this.syncbackRequestObject().props.folderId

    const eachMsg = ({message, box}) => {
      return db.Folder.findById(toFolderId).then((category) => {
        return box.moveFromBox(message.folderImapUID, category.name)
      })
    }

    return TaskHelpers.forEachMessageInThread({threadId, db, imap, callback: eachMsg})
  }
}
module.exports = MoveThreadToFolderIMAP
