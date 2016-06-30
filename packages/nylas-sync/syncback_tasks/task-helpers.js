const _ = require('underscore')

const TaskHelpers = {
  messagesForThreadByFolder: function messagesForThreadByFolder(db, threadId) {
    return db.Thread.findById(threadId).then((thread) => {
      return thread.getMessages()
    }).then((messages) => {
      return _.groupBy(messages, "folderId")
    })
  },

  forEachMessageInThread: function forEachMessageInThread({threadId, db, imap, callback}) {
    return TaskHelpers.messagesForThreadByFolder(db, threadId)
    .then((msgsInCategories) => {
      const cids = Object.keys(msgsInCategories);
      return db.Folder.findAll({where: {id: cids}})
      .each((category) =>
        imap.openBox(category.name, {readOnly: false}).then((box) => {
          return Promise.all(msgsInCategories[category.id].map((message) =>
            callback({message, category, box})
          )).then(() => box.closeBox())
        })
      )
    })
  },

  openMessageBox: function openMessageBox({messageId, db, imap}) {
    return db.Message.findById(messageId).then((message) => {
      return db.Folder.findById(message.folderId).then((category) => {
        return imap.openBox(category.name).then((box) => {
          return Promise.resolve({box, message})
        })
      })
    })
  },
}
module.exports = TaskHelpers
