const {Errors: {APIError}} = require('isomorphic-core')
const {SyncbackIMAPTask} = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')
const SyncTaskFactory = require('../sync-task-factory');

class MoveThreadToFolderIMAP extends SyncbackIMAPTask {
  description() {
    return `MoveThreadToFolder`;
  }

  affectsImapMessageUIDs() {
    return true
  }

  async * _run(db, imap, syncWorker) {
    const {Thread, Folder} = db
    const threadId = this.syncbackRequestObject().props.threadId
    const targetFolderId = this.syncbackRequestObject().props.folderId
    if (!threadId) {
      throw new APIError('threadId is required')
    }

    if (!targetFolderId) {
      throw new APIError('targetFolderId is required')
    }

    const targetFolder = yield Folder.findById(targetFolderId)
    if (!targetFolder) {
      throw new APIError('targetFolder not found', 404)
    }

    const thread = yield Thread.findById(threadId)
    if (!thread) {
      throw new APIError(`Can't find thread`, 404)
    }

    const threadMessages = yield thread.getMessages()
    yield IMAPHelpers.forEachFolderOfThread({
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
    yield syncOperation.run(db, imap, syncWorker)
  }
}
module.exports = MoveThreadToFolderIMAP
