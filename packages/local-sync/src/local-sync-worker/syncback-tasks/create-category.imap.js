const {SyncbackIMAPTask} = require('./syncback-task')

class CreateCategoryIMAP extends SyncbackIMAPTask {
  description() {
    return `CreateCategory`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const {accountId} = db
    const {objectClass, displayName} = this.syncbackRequestObject().props
    await imap.addBox(displayName)
    const id = db[objectClass].hash({boxName: displayName, accountId})
    const category = await db[objectClass].create({
      id,
      accountId,
      name: displayName,
    })
    return category.toJSON()
  }
}
module.exports = CreateCategoryIMAP
