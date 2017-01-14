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

    // Ben TODO this is super inefficient because it makes IMAP requests
    // one UID at a time, rather than gathering all the UIDs and making
    // a single removeLabels call.
    return IMAPHelpers.forEachMessageInThread({
      db,
      imap,
      threadId,
      async callback({message, box}) {
        await IMAPHelpers.setMessageLabels({message, db, box, labelIds})
        return IMAPHelpers.moveMessageToFolder({db, box, message, targetFolderId})
      },
    })
  }
}
module.exports = SetThreadFolderAndLabelsIMAP

