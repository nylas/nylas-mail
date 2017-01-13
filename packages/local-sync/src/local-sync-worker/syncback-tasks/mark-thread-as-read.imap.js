const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class MarkThreadAsRead extends SyncbackTask {
  description() {
    return `MarkThreadAsRead`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId

    const eachMsg = ({message, box}) => {
      return box.addFlags(message.folderImapUID, 'SEEN')
    }

    return TaskHelpers.forEachMessageInThread({threadId, db, imap, callback: eachMsg})
  }
}
module.exports = MarkThreadAsRead;
