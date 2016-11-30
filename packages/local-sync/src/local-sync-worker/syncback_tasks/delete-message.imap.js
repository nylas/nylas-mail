const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class DeleteMessageIMAP extends SyncbackTask {
  description() {
    return `DeleteMessage`;
  }

  run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId

    return TaskHelpers.openMessageBox({messageId, db, imap})
      .then(({box, message}) => {
        return box.addFlags(message.folderImapUID, 'DELETED')
      })
  }
}
module.exports = DeleteMessageIMAP;
