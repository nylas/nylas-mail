const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class UnstarThread extends SyncbackTask {
  description() {
    return `UnstarThread`;
  }

  run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId

    const eachMsg = ({message, box}) => {
      return box.delFlags(message.categoryImapUID, 'FLAGGED')
    }

    return TaskHelpers.forEachMessageInThread({threadId, db, imap, callback: eachMsg})
  }
}
module.exports = UnstarThread;
