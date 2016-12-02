const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class SetThreadLabelsIMAP extends SyncbackTask {
  description() {
    return `SetThreadLabels`;
  }

  async run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId
    const labelIds = this.syncbackRequestObject().props.labelIds

    // Ben TODO this is super inefficient because it makes IMAP requests
    // one UID at a time, rather than gathering all the UIDs and making
    // a single removeLabels call.
    return TaskHelpers.forEachMessageInThread({
      db,
      imap,
      threadId,
      async callback({message, box}) {
        return TaskHelpers.setMessageLabels({message, db, box, labelIds})
      },
    })
  }
}
module.exports = SetThreadLabelsIMAP
