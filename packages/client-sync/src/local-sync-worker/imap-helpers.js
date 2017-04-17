const _ = require('underscore')
const {Errors: {APIError}} = require('isomorphic-core')

const IMAPHelpers = {
  async messagesForThreadByFolder(db, threadId) {
    const thread = await db.Thread.findById(threadId)
    if (!thread) {
      throw new APIError(`IMAPHelpers.messagesForThreadByFolder - Can't find thread`, 404)
    }
    const messages = await thread.getMessages()
    return _.groupBy(messages, 'folderId')
  },

  async forEachFolderOfThread({db, imap, threadMessages, callback}) {
    if (!threadMessages.every(m => m.folderImapUID != null)) {
      throw new APIError('All messages in a thread require an IMAP uid to perform an action')
    }
    const {Folder} = db
    const msgsByFolder = _.groupBy(threadMessages, 'folderId')
    const folderIds = Object.keys(msgsByFolder)
    const folders = await Folder.findAll({where: {id: folderIds}})

    for (const folder of folders) {
      const msgsInFolder = msgsByFolder[folder.id]
      if (msgsInFolder.length === 0) { continue }
      const messageImapUIDs = msgsInFolder.map(m => m.folderImapUID)
      const box = await imap.openBox(folder.name, {readOnly: false})
      await callback({folder, messages: msgsInFolder, messageImapUIDs, box})
    }
  },

  async forEachLabelSetOfMessages({messages, callback}) {
    const messagesByLabelSet = new Map()
    const labelIdentifiersByLabelSet = new Map()

    await Promise.all(messages.map(async (message) => {
      const labels = await message.getLabels()
      if (!labels || labels.length === 0) {
        return
      }
      const labelIdentifiers = labels.map(l => l.imapLabelIdentifier())
      const labelSet = (
        labelIdentifiers
        .sort((l1, l2) => {
          if (l1.toLowerCase() === l2.toLowerCase()) {
            return 0
          }
          return l1.toLowerCase() < l2.toLowerCase() ? -1 : 1
        })
        .join('')
      )
      labelIdentifiersByLabelSet.set(labelSet, labelIdentifiers)
      if (messagesByLabelSet.has(labelSet)) {
        const currentMsgs = messagesByLabelSet.get(labelSet)
        messagesByLabelSet.set(labelSet, [...currentMsgs, message])
      } else {
        messagesByLabelSet.set(labelSet, [message])
      }
    }))

    for (const [labelSet, msgs] of messagesByLabelSet) {
      const labelIdentifiers = labelIdentifiersByLabelSet.get(labelSet)
      if (labelIdentifiers.length > 0) {
        await callback({messages: msgs, labelIdentifiers})
      }
    }
  },

  async openMessageBox({messageId, db, imap}) {
    const {Message} = db
    const message = await Message.findById(messageId)
    const folder = await message.getFolder()
    if (!folder) {
      throw new Error(`IMAPHelpers.openMessageBox - message does not have a folder`)
    }
    const box = await imap.openBox(folder.name)
    return {box, message}
  },

  async setLabelsForMessages({db, box, messages, labelIds}) {
    const sentLabel = await db.Label.find({where: {role: 'sent'}});
    if (!sentLabel) {
      throw new APIError('No Sent label present')
    }
    const sentLabelIdentifier = sentLabel.imapLabelIdentifier()
    if (!labelIds || labelIds.length === 0) {
      // If labelIds is empty, we need to get each message's labels and remove
      // them, because an empty array is invalid input for `setLabels`
      return IMAPHelpers.forEachLabelSetOfMessages({
        messages,
        async callback({messages: msgs, labelIdentifiers}) {
          // We can't remove the Sent label in gmail, otherwise the operation will
          // fail silently!
          const labelsToRemove = labelIdentifiers.filter(l => l !== sentLabelIdentifier)
          if (labelsToRemove.length > 0) {
            await box.removeLabels(msgs.map(m => m.folderImapUID), labelsToRemove)
          }
        },
      })
    }

    const labelsToSet = (
      await db.Label.findAll({where: {id: labelIds}})
      .map(label => label.imapLabelIdentifier())
    )
    return IMAPHelpers.forEachLabelSetOfMessages({
      messages,
      async callback({messages: msgs, labelIdentifiers}) {
        const msgLabelsContainSent = labelIdentifiers.find(l => l === sentLabelIdentifier)
        const labelsToSetContainSent = labelsToSet.find(l => l === sentLabelIdentifier)

        let actualLabelsToSet = [...labelsToSet]
        if (!msgLabelsContainSent && labelsToSetContainSent) {
          // We can't try to add the Sent label in gmail, otherwise the operation will
          // fail silently!
          actualLabelsToSet = actualLabelsToSet.filter(l => l !== sentLabelIdentifier)
        }
        if (msgLabelsContainSent && !labelsToSetContainSent) {
          // If we reach this condition, it means that we want to add
          // labelsToSet, but we cant overwrite the Sent label, so we just add it to the
          // labelsToSet
          actualLabelsToSet.push(sentLabel.imapLabelIdentifier())
        }

        if (actualLabelsToSet.length > 0) {
          await box.setLabels(msgs.map(m => m.folderImapUID), actualLabelsToSet)
        }
      },
    })
  },
}
module.exports = IMAPHelpers
