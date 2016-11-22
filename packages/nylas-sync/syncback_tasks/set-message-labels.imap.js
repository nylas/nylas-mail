const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class SetMessageLabelsIMAP extends SyncbackTask {
  description() {
    return `SetMessageLabels`;
  }

  run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId
    const labelIds = this.syncbackRequestObject().props.labelIds

    return TaskHelpers.openMessageBox({messageId, db, imap})
    .then(({box, message}) => {
      if (!labelIds || labelIds.length === 0) {
        return message.getLabels().then((labels) => {
          const labelNames = labels.map(({name}) => name)
          return box.removeLabels(message.folderImapUID, labelNames)
        })
      }
      return db.Label.findAll({
        where: {
          id: {'in': labelIds},
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
