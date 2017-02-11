const {SyncbackIMAPTask} = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class DeleteMessageIMAP extends SyncbackIMAPTask {
  description() {
    return `DeleteMessage`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId
    const {box, message} = await IMAPHelpers.openMessageBox({messageId, db, imap})
    return box.addFlags(message.folderImapUID, ['DELETED'])
  }
}
module.exports = DeleteMessageIMAP;
