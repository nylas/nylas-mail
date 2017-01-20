const {Errors: {APIError}} = require('isomorphic-core')
const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class MarkThreadAsUnread extends SyncbackTask {
  description() {
    return `MarkThreadAsUnread`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const {sequelize, Thread} = db
    const threadId = this.syncbackRequestObject().props.threadId
    if (!threadId) {
      throw new APIError('threadId is required')
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
      callback({messageImapUIDs, box}) {
        return box.delFlags(messageImapUIDs, 'SEEN')
      },
    })
    // If IMAP succeeds, save the model updates
    await sequelize.transaction(async (transaction) => {
      await Promise.all(threadMessages.map((m) => m.update({unread: true}, {transaction})))
      await thread.update({unreadCount: threadMessages.length}, {transaction})
    })
  }
}
module.exports = MarkThreadAsUnread;
