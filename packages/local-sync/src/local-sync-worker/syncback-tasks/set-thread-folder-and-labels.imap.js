const {Errors: {APIError}} = require('isomorphic-core')
const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class SetThreadFolderAndLabelsIMAP extends SyncbackTask {
  description() {
    return `SetThreadFolderAndLabels`;
  }

  affectsImapMessageUIDs() {
    return true
  }

  async run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId
    const labelIds = this.syncbackRequestObject().props.labelIds
    const targetFolderId = this.syncbackRequestObject().props.folderId

    if (!targetFolderId) {
      throw new APIError('targetFolderId is required')
    }

    const targetFolder = await db.Folder.findById(targetFolderId)
    if (!targetFolder) {
      throw new APIError('targetFolder not found', 404)
    }

    return IMAPHelpers.forEachFolderOfThread({
      db,
      imap,
      threadId,
      async callback({box, folder, messages, messageImapUIDs}) {
        await IMAPHelpers.setLabelsForMessages({db, box, messages, labelIds})

        if (folder.id === targetFolderId) {
          return Promise.resolve()
        }
        return box.moveFromBox(messageImapUIDs, targetFolder.name)
      },
    })
  }
}
module.exports = SetThreadFolderAndLabelsIMAP

