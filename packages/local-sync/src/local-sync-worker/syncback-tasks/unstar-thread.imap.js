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

    const eachMsg = ({box, messageImapUIDs}) => {
      return box.delFlags(messageImapUIDs, 'FLAGGED')
    }

    return IMAPHelpers.forEachFolderOfThread({db, imap, threadId, callback: eachMsg})
  }
}
module.exports = UnstarThread;
