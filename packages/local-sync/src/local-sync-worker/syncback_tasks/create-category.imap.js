const SyncbackTask = require('./syncback-task')

class CreateCategoryIMAP extends SyncbackTask {
  description() {
    return `CreateCategory`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const {objectId, displayName} = this.syncbackRequestObject().props
    await imap.addBox(displayName)
    return {categoryId: objectId}
  }
}
module.exports = CreateCategoryIMAP
