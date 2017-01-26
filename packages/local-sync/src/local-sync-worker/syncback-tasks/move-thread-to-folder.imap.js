const {Errors: {APIError}} = require('isomorphic-core')
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
    const {sequelize, Thread, Folder} = db
    const threadId = this.syncbackRequestObject().props.threadId
    const targetFolderId = this.syncbackRequestObject().props.folderId
    if (!threadId) {
      throw new APIError('threadId is required')
    }

    if (!targetFolderId) {
      throw new APIError('targetFolderId is required')
    }

    const targetFolder = await Folder.findById(targetFolderId)
    if (!targetFolder) {
      throw new APIError('targetFolder not found', 404)
    }

    const thread = await Thread.findById(threadId)
    if (!thread) {
      throw new APIError(`Can't find thread`, 404)
    }

    const threadMessages = await thread.getMessages()
    await IMAPHelpers.forEachFolderOfThread({
      db,
      imap,
      threadMessages,
      async callback({box, folder, messageImapUIDs}) {
        if (folder.id === targetFolderId) {
          return Promise.resolve()
        }
        return box.moveFromBox(messageImapUIDs, targetFolder.name)
      },
    })

    // If IMAP succeeds, save the model updates
    await sequelize.transaction(async (transaction) => {
      await Promise.all(threadMessages.map(async (m) => {
        await m.update({folderImapUID: null}, transaction)
        await m.setFolder(targetFolder, {transaction})
      }))
      await thread.setFolders([targetFolder], {transaction})
    })
  }
}
module.exports = MoveThreadToFolderIMAP
