const SyncbackTask = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class StarMessageIMAP extends SyncbackTask {
  description() {
    return `StarMessage`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId

    return IMAPHelpers.openMessageBox({messageId, db, imap})
      .then(({box, message}) => {
        return box.addFlags(message.folderImapUID, 'FLAGGED')
      })
  }
}
module.exports = StarMessageIMAP;
