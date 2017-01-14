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

    // Ben TODO this is super inefficient because it makes IMAP requests
    // one UID at a time, rather than gathering all the UIDs and making
    // a single removeLabels call.
    return IMAPHelpers.forEachMessageInThread({
      db,
      imap,
      threadId,
      async callback({message, box}) {
        return IMAPHelpers.setMessageLabels({message, db, box, labelIds})
      },
    })
  }
}
module.exports = SetThreadLabelsIMAP
