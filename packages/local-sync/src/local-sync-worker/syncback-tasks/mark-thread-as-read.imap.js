const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class MarkThreadAsRead extends SyncbackTask {
  description() {
    return `MarkThreadAsRead`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId

    const eachMsg = ({messageImapUIDs, box}) => {
      return box.addFlags(messageImapUIDs, 'SEEN')
    }

    return IMAPHelpers.forEachFolderOfThread({threadId, db, imap, callback: eachMsg})
  }
}
module.exports = MarkThreadAsRead;
