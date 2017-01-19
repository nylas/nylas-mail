const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class MarkThreadAsUnread extends SyncbackTask {
  description() {
    return `MarkThreadAsUnread`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId

    const eachMsg = ({messageImapUIDs, box}) => {
      return box.delFlags(messageImapUIDs, 'SEEN')
    }

    return IMAPHelpers.forEachFolderOfThread({threadId, db, imap, callback: eachMsg})
  }
}
module.exports = MarkThreadAsUnread;
