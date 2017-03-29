const {Errors: {APIError}} = require('isomorphic-core')
const {SyncbackIMAPTask} = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class StarThread extends SyncbackIMAPTask {
  description() {
    return `StarThread`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async * _run(db, imap) {
    const {sequelize, Thread} = db
    const threadId = this.syncbackRequestObject().props.threadId
    if (!threadId) {
      throw new APIError('threadId is required')
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
      callback({messageImapUIDs, box}) {
        return box.addFlags(messageImapUIDs, 'FLAGGED')
      },
    })
    // If IMAP succeeds, save the model updates
    yield sequelize.transaction(async (transaction) => {
      await Promise.all(threadMessages.map((m) => m.update({starred: true}, {transaction})))
      await thread.update({starredCount: threadMessages.length}, {transaction})
    })
  }
}
module.exports = StarThread;
