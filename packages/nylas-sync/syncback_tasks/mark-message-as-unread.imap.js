const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class MarkMessageAsUnreadIMAP extends SyncbackTask {
  description() {
    return `MarkMessageAsUnread`;
  }

  run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId

    return TaskHelpers.openMessageBox({messageId, db, imap})
      .then(({box, message}) => {
        return box.delFlags(message.categoryImapUID, 'SEEN')
      })
  }
}
module.exports = MarkMessageAsUnreadIMAP;
