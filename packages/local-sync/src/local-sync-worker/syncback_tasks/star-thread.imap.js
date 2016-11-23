const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class StarThread extends SyncbackTask {
  description() {
    return `StarThread`;
  }

  run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId

    const eachMsg = ({message, box}) => {
      return box.addFlags(message.folderImapUID, 'FLAGGED')
    }

    return TaskHelpers.forEachMessageInThread({threadId, db, imap, callback: eachMsg})
  }
}
module.exports = StarThread;
