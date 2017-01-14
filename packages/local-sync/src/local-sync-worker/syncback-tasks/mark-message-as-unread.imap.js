const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class MarkMessageAsUnreadIMAP extends SyncbackTask {
  description() {
    return `MarkMessageAsUnread`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId

    return IMAPHelpers.openMessageBox({messageId, db, imap})
      .then(({box, message}) => {
        return box.delFlags(message.folderImapUID, 'SEEN')
      })
  }
}
module.exports = MarkMessageAsUnreadIMAP;
