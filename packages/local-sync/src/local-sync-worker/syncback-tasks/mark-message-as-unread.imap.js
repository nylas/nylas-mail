const {SyncbackIMAPTask} = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class MarkMessageAsUnreadIMAP extends SyncbackIMAPTask {
  description() {
    return `MarkMessageAsUnread`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId

    const {box, message} = await IMAPHelpers.openMessageBox({messageId, db, imap})
    return box.delFlags(message.folderImapUID, 'SEEN')
  }
}
module.exports = MarkMessageAsUnreadIMAP;
