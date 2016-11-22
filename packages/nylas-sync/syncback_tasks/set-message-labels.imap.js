const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class SetMessageLabelsIMAP extends SyncbackTask {
  description() {
    return `SetMessageLabels`;
  }

  run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId
    const targetLabelIds = this.syncbackRequestObject().props.labelIds

    return TaskHelpers.openMessageBox({messageId, db, imap})
      .then(({box, message}) => {
        if (!targetLabelIds || targetLabelIds.length === 0) {
          return message.getLabels().then((labels) => {
            const labelNames = labels.map(({name}) => name)
            return box.removeLabels(message.folderImapUID, labelNames)
          })
        }
        return db.Label.findAll({
          where: {
            id: {in: targetLabelIds},
          },
        })
        .then((labels) => {
          const labelNames = labels.map(({name}) => name)
          return box.setLabels(message.folderImapUID, labelNames)
        })
      })
  }
}
module.exports = SetMessageLabelsIMAP
