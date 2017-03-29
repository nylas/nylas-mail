const {SyncbackIMAPTask} = require('./syncback-task')

class CreateCategoryIMAP extends SyncbackIMAPTask {
  description() {
    return `CreateCategory`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async * _run(db, imap) {
    const {accountId} = db
    const {objectClass, displayName} = this.syncbackRequestObject().props
    yield imap.addBox(displayName)
    const id = db[objectClass].hash({boxName: displayName, accountId})
    const category = yield db[objectClass].create({
      id,
      accountId,
      name: displayName,
    })
    return category.toJSON()
  }
}
module.exports = CreateCategoryIMAP
