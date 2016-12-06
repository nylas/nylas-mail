const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class DeleteMessageIMAP extends SyncbackTask {
  description() {
    return `DeleteMessage`;
  }

  async run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId
    const {box, message} = await TaskHelpers.openMessageBox({messageId, db, imap})
    return box.addFlags(message.folderImapUID, ['DELETED'])
  }
}
module.exports = DeleteMessageIMAP;
