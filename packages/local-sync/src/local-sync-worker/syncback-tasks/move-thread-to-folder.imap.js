const {Errors: {APIError}} = require('isomorphic-core')
const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')
const SyncTaskFactory = require('../sync-task-factory');

class MoveThreadToFolderIMAP extends SyncbackTask {
  description() {
    return `MoveThreadToFolder`;
  }

  affectsImapMessageUIDs() {
    return true
  }

  async run(db, imap) {
    const {Thread, Folder} = db
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

    // If IMAP succeeds, fetch any new messages in the target folder which
    // should include the messages we just moved there
    // The sync operation will save the changes to the database.
    // TODO add transaction
    const syncOperation = SyncTaskFactory.create('FetchNewMessagesInFolder', {
      account: this._account,
      folder: targetFolder,
    })
    await syncOperation.run(db, imap)
  }
}
module.exports = MoveThreadToFolderIMAP
