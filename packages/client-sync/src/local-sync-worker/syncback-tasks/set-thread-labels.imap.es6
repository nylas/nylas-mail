const {Errors: {APIError}} = require('isomorphic-core')
const {SyncbackIMAPTask} = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class SetThreadLabelsIMAP extends SyncbackIMAPTask {
  description() {
    return `SetThreadLabels`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async * _run(db, imap) {
    const {sequelize, Thread} = db
    const threadId = this.syncbackRequestObject().props.threadId
    const labelIds = this.syncbackRequestObject().props.labelIds
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
      async callback({box, messages}) {
        return IMAPHelpers.setLabelsForMessages({db, box, messages, labelIds})
      },
    })

    // If IMAP succeeds, save the model updates
    yield sequelize.transaction(async (transaction) => {
      await Promise.all(threadMessages.map(async (m) => m.setLabels(labelIds, {transaction})))
      await thread.setLabels(labelIds, {transaction})
    })
  }
}
module.exports = SetThreadLabelsIMAP
