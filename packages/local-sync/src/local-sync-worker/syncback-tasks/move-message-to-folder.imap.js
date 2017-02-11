const {Errors: {APIError}} = require('isomorphic-core')
const {SyncbackIMAPTask} = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class MoveMessageToFolderIMAP extends SyncbackIMAPTask {
  description() {
    return `MoveMessageToFolder`;
  }

  affectsImapMessageUIDs() {
    return true
  }

  async run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId
    const targetFolderId = this.syncbackRequestObject().props.folderId

    if (!targetFolderId) {
      throw new APIError('targetFolderId is required')
    }

    const targetFolder = await db.Folder.findById(targetFolderId)
    if (!targetFolder) {
      throw new APIError('targetFolder not found', 404)
    }

    const {box, message} = await IMAPHelpers.openMessageBox({messageId, db, imap})
    return box.moveFromBox(message.folderImapUID, targetFolder.name)
  }
}
module.exports = MoveMessageToFolderIMAP
