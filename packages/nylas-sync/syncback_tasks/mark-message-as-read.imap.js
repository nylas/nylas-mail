const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class MarkMessageAsReadIMAP extends SyncbackTask {
  description() {
    return `MarkMessageAsRead`;
  }

  run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId

    return TaskHelpers.openMessageBox({messageId, db, imap})
      .then(({box, message}) => {
        return box.addFlags(message.categoryImapUID, 'SEEN')
      })
  }
}
module.exports = MarkMessageAsReadIMAP;
