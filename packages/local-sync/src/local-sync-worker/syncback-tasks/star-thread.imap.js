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

    const eachMsg = ({box, messageImapUIDs}) => {
      return box.addFlags(messageImapUIDs, 'FLAGGED')
    }

    return IMAPHelpers.forEachFolderOfThread({db, imap, threadId, callback: eachMsg})
  }
}
module.exports = StarThread;
