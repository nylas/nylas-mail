const _ = require('underscore')
const {PromiseUtils} = require('isomorphic-core')

const TaskHelpers = {
  messagesForThreadByFolder(db, threadId) {
    return Promise.resolve(db.Thread.findById(threadId).then((thread) => {
      return thread.getMessages()
    })).then((messages) => {
      return _.groupBy(messages, "folderId")
    })
  },

  forEachMessageInThread({threadId, db, imap, callback}) {
    return TaskHelpers.messagesForThreadByFolder(db, threadId)
    .then((msgsInCategories) => {
      const cids = Object.keys(msgsInCategories);
      return PromiseUtils.each(db.Folder.findAll({where: {id: cids}}), (category) =>
        imap.openBox(category.name, {readOnly: false}).then((box) =>
          Promise.all(msgsInCategories[category.id].map((message) =>
            callback({message, category, box})
          )).then(() => box.closeBox())
        )
      )
    })
  },

  openMessageBox({messageId, db, imap}) {
    return Promise.resolve(db.Message.findById(messageId).then((message) => {
      return db.Folder.findById(message.folderId).then((category) => {
        return imap.openBox(category.name).then((box) => {
          return Promise.resolve({box, message})
        })
      })
    }))
  },

  async moveMessageToFolder({db, box, message, targetFolderId}) {
    if (!targetFolderId) {
      throw new Error('TaskHelpers.moveMessageToFolder: targetFolderId is required')
    }
    if (targetFolderId === message.folderId) {
      return Promise.resolve()
    }
    const targetFolder = await db.Folder.findById(targetFolderId)
    if (!targetFolder) {
      return Promise.resolve()
    }
    return box.moveFromBox(message.folderImapUID, targetFolder.name)
  },

  async setMessageLabels({db, box, message, labelIds}) {
    if (!labelIds || labelIds.length === 0) {
      const labels = await message.getLabels()
      if (labels.length === 0) {
        return Promise.resolve()
      }
      const labelIdentifiers = labels.map(label => label.imapLabelIdentifier())
      return box.removeLabels(message.folderImapUID, labelIdentifiers)
    }

    const labels = await db.Label.findAll({where: {id: labelIds}});
    const labelIdentifiers = labels.map(label => label.imapLabelIdentifier());
    return box.setLabels(message.folderImapUID, labelIdentifiers)
  },
}
module.exports = TaskHelpers
