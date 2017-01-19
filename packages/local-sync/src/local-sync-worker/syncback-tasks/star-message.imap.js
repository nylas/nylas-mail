const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class StarMessageIMAP extends SyncbackTask {
  description() {
    return `StarMessage`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId

    const {box, message} = await IMAPHelpers.openMessageBox({messageId, db, imap})
    return box.addFlags(message.folderImapUID, 'FLAGGED')
  }
}
module.exports = StarMessageIMAP;
