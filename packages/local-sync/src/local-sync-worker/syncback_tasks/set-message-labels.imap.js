const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class SetMessageLabelsIMAP extends SyncbackTask {
  description() {
    return `SetMessageLabels`;
  }

  async run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId
    const labelIds = this.syncbackRequestObject().props.labelIds

    const {box, message} = await TaskHelpers.openMessageBox({messageId, db, imap})
    return TaskHelpers.setMessageLabels({message, db, box, labelIds})
  }
}
module.exports = SetMessageLabelsIMAP
