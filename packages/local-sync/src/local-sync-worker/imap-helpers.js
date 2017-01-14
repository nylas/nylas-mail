const _ = require('underscore')
const {PromiseUtils, Errors: {APIError}} = require('isomorphic-core')

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
          ))
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
      throw new APIError('TaskHelpers.moveMessageToFolder: targetFolderId is required')
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

  async saveSentMessage({db, imap, provider, rawMime, headerMessageId}) {
    if (provider !== 'gmail') {
      const sentFolder = await db.Folder.find({where: {role: 'sent'}});
      if (!sentFolder) { throw new APIError('Could not save message to sent folder.') }

      const box = await imap.openBox(sentFolder.name);
      return box.append(rawMime, {flags: 'SEEN'});
    }

    // Gmail, we need to add the message to all mail and add the sent label
    const sentLabel = await db.Label.find({where: {role: 'sent'}});
    const allMail = await db.Folder.find({where: {role: 'all'}});
    if (sentLabel && allMail) {
      const box = await imap.openBox(allMail.name);
      await box.append(rawMime, {flags: 'SEEN'})
      const uids = await box.search([['HEADER', 'Message-ID', headerMessageId]])
      // There should only be one uid in the array
      return box.setLabels(uids[0], '\\Sent');
    }

    throw new APIError('Could not save message to sent folder.')
  },

  async deleteGmailSentMessages({db, imap, provider, headerMessageId}) {
    if (provider !== 'gmail') { return }

    const trash = await db.Folder.find({where: {role: 'trash'}});
    if (!trash) { throw new APIError(`Could not find folder with role 'trash'.`) }

    const allMail = await db.Folder.find({where: {role: 'all'}});
    if (!allMail) { throw new APIError(`Could not find folder with role 'all'.`) }

    // Move the message from all mail to trash and then delete it from there
    const steps = [
      {folder: allMail, deleteFn: (box, uid) => box.moveFromBox(uid, trash.name)},
      {folder: trash, deleteFn: (box, uid) => box.addFlags(uid, 'DELETED')},
    ]

    for (const {folder, deleteFn} of steps) {
      const box = await imap.openBox(folder.name);
      const uids = await box.search([['HEADER', 'Message-ID', headerMessageId]])
      for (const uid of uids) {
        await deleteFn(box, uid);
      }
      await box.closeBox();
    }
  },
}
module.exports = TaskHelpers
