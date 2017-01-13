const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class MarkMessageAsReadIMAP extends SyncbackTask {
  description() {
    return `MarkMessageAsRead`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId

    return TaskHelpers.openMessageBox({messageId, db, imap})
      .then(({box, message}) => {
        return box.addFlags(message.folderImapUID, 'SEEN')
      })
  }
}
module.exports = MarkMessageAsReadIMAP;
