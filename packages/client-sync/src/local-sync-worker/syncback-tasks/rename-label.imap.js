const {Errors: {APIError}} = require('isomorphic-core')
const {SyncbackIMAPTask} = require('./syncback-task')

class RenameLabelIMAP extends SyncbackIMAPTask {
  description() {
    return `RenameLabel`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const {sequelize, accountId, Label} = db
    const {labelId, newLabelName} = this.syncbackRequestObject().props
    const oldLabel = await Label.findById(labelId)
    await imap.renameBox(oldLabel.name, newLabelName);

    // After IMAP succeeds, update the db
    const newId = Label.hash({boxName: newLabelName, accountId})
    let newLabel;
    await sequelize.transaction(async (transaction) => {
      newLabel = await Label.create({
        id: newId,
        accountId,
        name: newLabelName,
      }, {transaction})

      // We can't do batch updates because we need to generate deltas for each
      // message and thread
      const messages = await oldLabel.getMessages({
        transaction,
        attributes: ['id'],
        include: [{model: Label, as: 'labels', attributes: ['id']}],
      })
      await Promise.all(messages.map(async (m) => {
        const nextLabels = [
          newLabel,
          ...m.labels.filter(l => l.id !== oldLabel.id),
        ]
        await m.setLabels(nextLabels, {transaction})
        await m.save({transaction})
      }))
      const threads = await oldLabel.getThreads({
        transaction,
        attributes: ['id'],
        include: [{model: Label, as: 'labels', attributes: ['id']}],
      })
      await Promise.all(threads.map(async (t) => {
        const nextLabels = [
          newLabel,
          ...t.labels.filter(l => l.id !== oldLabel.id),
        ]
        await t.setLabels(nextLabels, {transaction})
        await t.save({transaction})
      }))
      await oldLabel.destroy({transaction})
    })
    if (!newLabel) {
      throw new APIError(`Error renaming label - can't save to database`)
    }
    return newLabel.toJSON()
  }
}
module.exports = RenameLabelIMAP
