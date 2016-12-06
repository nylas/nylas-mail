const SyncbackTask = require('./syncback-task')

class CreateCategoryIMAP extends SyncbackTask {
  description() {
    return `CreateCategory`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const syncbackRequestObject = this.syncbackRequestObject()
    const displayName = syncbackRequestObject.props.displayName
    await imap.addBox(displayName)
  }
}
module.exports = CreateCategoryIMAP
