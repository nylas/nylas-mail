const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

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

    return IMAPHelpers.forEachMessageInThread({
      db,
      imap,
      threadId,
      async callback({message, box}) {
        return IMAPHelpers.moveMessageToFolder({db, box, message, targetFolderId})
      },
    })
  }
}
module.exports = MoveThreadToFolderIMAP
