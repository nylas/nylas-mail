const {SyncbackIMAPTask} = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class UnstarMessageIMAP extends SyncbackIMAPTask {
  description() {
    return `UnstarMessage`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId

    const {box, message} = await IMAPHelpers.openMessageBox({messageId, db, imap})
    return box.delFlags(message.folderImapUID, 'FLAGGED')
  }
}
module.exports = UnstarMessageIMAP;
