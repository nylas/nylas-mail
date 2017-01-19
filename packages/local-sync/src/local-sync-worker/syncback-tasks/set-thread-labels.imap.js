const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class SetThreadLabelsIMAP extends SyncbackTask {
  description() {
    return `SetThreadLabels`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId
    const labelIds = this.syncbackRequestObject().props.labelIds

    return IMAPHelpers.forEachFolderOfThread({
      db,
      imap,
      threadId,
      async callback({box, messages}) {
        return IMAPHelpers.setLabelsForMessages({db, box, messages, labelIds})
      },
    })
  }
}
module.exports = SetThreadLabelsIMAP
