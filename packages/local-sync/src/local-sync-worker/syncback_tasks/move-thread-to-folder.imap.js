const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class MoveThreadToFolderIMAP extends SyncbackTask {
  description() {
    return `MoveThreadToFolder`;
  }

  affectsImapMessageUIDs() {
    return true
  }

  async run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId
    const targetFolderId = this.syncbackRequestObject().props.folderId

    return TaskHelpers.forEachMessageInThread({
      db,
      imap,
      threadId,
      async callback({message, box}) {
        return TaskHelpers.moveMessageToFolder({db, box, message, targetFolderId})
      },
    })
  }
}
module.exports = MoveThreadToFolderIMAP
