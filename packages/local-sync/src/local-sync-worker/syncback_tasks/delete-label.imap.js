const SyncbackTask = require('./syncback-task')

class DeleteLabelIMAP extends SyncbackTask {
  description() {
    return `DeleteLabel`;
  }

  async run(db, imap) {
    const labelId = this.syncbackRequestObject().props.labelId
    const label = await db.Label.findById(labelId)
    return imap.delBox(label.name);
  }
}
module.exports = DeleteLabelIMAP
