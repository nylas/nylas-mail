const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class MoveMessageToFolderIMAP extends SyncbackTask {
  description() {
    return `MoveMessageToFolder`;
  }

  affectsImapMessageUIDs() {
    return true
  }

  async run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId
    const targetFolderId = this.syncbackRequestObject().props.folderId

    const {box, message} = await IMAPHelpers.openMessageBox({messageId, db, imap})
    return IMAPHelpers.moveMessageToFolder({db, box, message, targetFolderId})
  }
}
module.exports = MoveMessageToFolderIMAP
