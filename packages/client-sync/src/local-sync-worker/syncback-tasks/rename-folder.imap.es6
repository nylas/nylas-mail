const {Errors: {APIError}} = require('isomorphic-core')
const {SyncbackIMAPTask} = require('./syncback-task')

class RenameFolderIMAP extends SyncbackIMAPTask {
  description() {
    return `RenameFolder`;
  }

  affectsImapMessageUIDs() {
    return true
  }

  async * _run(db, imap) {
    const {sequelize, accountId, Folder} = db
    const {folderId, newFolderName} = this.syncbackRequestObject().props.folderId
    const oldFolder = yield Folder.findById(folderId)
    yield imap.renameBox(oldFolder.name, newFolderName);

    // After IMAP succeeds, update the db
    const newId = Folder.hash({boxName: newFolderName, accountId})
    let newFolder;
    yield sequelize.transaction(async (transaction) => {
      newFolder = await Folder.create({
        id: newId,
        accountId,
        name: newFolderName,
      }, {transaction})

      // We can't do batch updates because we need to generate deltas for each
      // message and thread
      const messages = await oldFolder.getMessages({
        transaction,
        attributes: ['id'],
        include: [{model: Folder, as: 'folders', attributes: ['id']}],
      })
      await Promise.all(messages.map(async (m) => {
        await m.setFolder(newFolder, {transaction})
        await m.save({transaction})
      }))
      const threads = await oldFolder.getThreads({
        transaction,
        attributes: ['id'],
        include: [{model: Folder, as: 'folders', attributes: ['id']}],
      })
      await Promise.all(threads.map(async (t) => {
        const nextFolders = [
          newFolder,
          ...t.folders.filter(f => f.id !== oldFolder.id),
        ]
        await t.setFolders(nextFolders, {transaction})
        await t.save({transaction})
      }))
      await oldFolder.destroy({transaction})
    })
    if (!newFolder) {
      throw new APIError(`Error renaming folder - can't save to database`)
    }
    return newFolder.toJSON()
  }
}
module.exports = RenameFolderIMAP
