const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class SetThreadLabelsIMAP extends SyncbackTask {
  description() {
    return `SetThreadLabels`;
  }

  async run(db, imap) {
    const threadId = this.syncbackRequestObject().props.threadId
    const labelIds = this.syncbackRequestObject().props.labelIds

    const labels = await db.Label.findAll({where: {id: labelIds}});
    const gmailLabelIdentifiers = labels.map((label) => {
      if (label.role) {
        return `\\${label.role[0].toUpperCase()}${label.role.slice(1)}`
      }
      return label.name;
    });


    // Ben TODO this is super inefficient because it makes IMAP requests
    // one UID at a time, rather than gathering all the UIDs and making
    // a single removeLabels call.
    return TaskHelpers.forEachMessageInThread({
      db,
      imap,
      threadId,
      callback: ({message, box}) => {
        return box.setLabels(message.folderImapUID, gmailLabelIdentifiers)
      },
    })
  }
}
module.exports = SetThreadLabelsIMAP
