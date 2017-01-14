const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class StarThread extends SyncbackTask {
  description() {
    return `StarThread`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId

    const eachMsg = ({message, box}) => {
      return box.addFlags(message.folderImapUID, 'FLAGGED')
    }

    return IMAPHelpers.forEachMessageInThread({threadId, db, imap, callback: eachMsg})
  }
}
module.exports = StarThread;
