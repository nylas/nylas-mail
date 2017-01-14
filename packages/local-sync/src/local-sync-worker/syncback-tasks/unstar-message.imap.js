const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class UnstarMessageIMAP extends SyncbackTask {
  description() {
    return `UnstarMessage`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId

    return IMAPHelpers.openMessageBox({messageId, db, imap})
      .then(({box, message}) => {
        return box.delFlags(message.folderImapUID, 'FLAGGED')
      })
  }
}
module.exports = UnstarMessageIMAP;
