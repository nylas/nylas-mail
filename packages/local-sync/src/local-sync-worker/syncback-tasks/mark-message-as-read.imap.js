const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class MarkMessageAsReadIMAP extends SyncbackTask {
  description() {
    return `MarkMessageAsRead`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId

    const {box, message} = await IMAPHelpers.openMessageBox({messageId, db, imap})
    return box.addFlags(message.folderImapUID, 'SEEN')
  }
}
module.exports = MarkMessageAsReadIMAP;
