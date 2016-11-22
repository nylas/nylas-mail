const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class SetThreadLabelsIMAP extends SyncbackTask {
  description() {
    return `SetThreadLabels`;
  }

  run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId
    const labelIds = this.syncbackRequestObject().props.labelIds

    if (!labelIds || labelIds.length === 0) {
      return TaskHelpers.forEachMessageInThread({
        db,
        imap,
        threadId,
        callback: ({message, box}) => {
          return message.getLabels().then((labels) => {
            const labelNames = labels.map(({name}) => name)
            return box.removeLabels(message.folderImapUID, labelNames)
          })
        },
      })
    }
    return TaskHelpers.forEachMessageInThread({
      db,
      imap,
      threadId,
      callback: ({message, box}) => {
        return db.Label.findAll({
          where: {
            id: {'in': labelIds},
          },
        })
        .then((labels) => {
          const labelNames = labels.map(({name}) => name)
          return box.setLabels(message.folderImapUID, labelNames)
        })
      },
    })
  }
}
module.exports = SetThreadLabelsIMAP
