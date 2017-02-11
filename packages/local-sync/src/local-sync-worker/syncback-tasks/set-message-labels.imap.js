const {SyncbackIMAPTask} = require('./syncback-task')
const IMAPHelpers = require('../imap-helpers')

class SetMessageLabelsIMAP extends SyncbackIMAPTask {
  description() {
    return `SetMessageLabels`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId
    const labelIds = this.syncbackRequestObject().props.labelIds

    const {box, message} = await IMAPHelpers.openMessageBox({messageId, db, imap})
    return IMAPHelpers.setLabelsForMessages({db, box, labelIds, messages: [message]})
  }
}
module.exports = SetMessageLabelsIMAP
