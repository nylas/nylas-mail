const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class SetThreadLabelsIMAP extends SyncbackTask {
  description() {
    return `SetThreadLabels`;
  }

  async run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId
    const labelIds = this.syncbackRequestObject().props.labelIds

    if (!labelIds || labelIds.length === 0) {
      return TaskHelpers.forEachMessageInThread({
        db,
        imap,
        threadId,
        callback: ({message, box}) => {
          return message.getLabels().then((labels) => {
            const labelIdentifiers = labels.map(label => label.imapLabelIdentifier())
            return box.removeLabels(message.folderImapUID, labelIdentifiers)
          })
        },
      })
    }

    const labels = await db.Label.findAll({where: {id: labelIds}});
    const labelIdentifiers = labels.map(label => label.imapLabelIdentifier());

    // Ben TODO this is super inefficient because it makes IMAP requests
    // one UID at a time, rather than gathering all the UIDs and making
    // a single removeLabels call.
    return TaskHelpers.forEachMessageInThread({
      db,
      imap,
      threadId,
      callback: ({message, box}) => {
        return box.setLabels(message.folderImapUID, labelIdentifiers)
      },
    })
  }
}
module.exports = SetThreadLabelsIMAP
