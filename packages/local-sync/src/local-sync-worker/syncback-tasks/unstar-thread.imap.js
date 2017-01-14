const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class UnstarThread extends SyncbackTask {
  description() {
    return `UnstarThread`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId

    const eachMsg = ({message, box}) => {
      return box.delFlags(message.folderImapUID, 'FLAGGED')
    }

    return IMAPHelpers.forEachMessageInThread({threadId, db, imap, callback: eachMsg})
  }
}
module.exports = UnstarThread;
