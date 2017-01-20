const SyncbackTask = require('./syncback-task')

class DeleteLabelIMAP extends SyncbackTask {
  description() {
    return `DeleteLabel`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const {labelId} = this.syncbackRequestObject().props.labelId
    const label = await db.Label.findById(labelId)
    if (!label) {
      // Nothing to delete!
      return
    }
    await imap.delBox(label.name);

    // If IMAP succeeds, save updates to the db
    await label.destroy()
  }
}
module.exports = DeleteLabelIMAP
