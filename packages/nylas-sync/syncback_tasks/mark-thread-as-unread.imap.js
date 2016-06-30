const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class MarkThreadAsUnread extends SyncbackTask {
  description() {
    return `MarkThreadAsUnread`;
  }

  run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId

    const eachMsg = ({message, box}) => {
      return box.delFlags(message.categoryUID, 'SEEN')
    }

    return TaskHelpers.forEachMessageInThread({threadId, db, imap, callback: eachMsg})
  }
}
module.exports = MarkThreadAsUnread;
