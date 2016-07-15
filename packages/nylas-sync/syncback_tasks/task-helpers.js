const _ = require('underscore')
const {PromiseUtils} = require('nylas-core')

const TaskHelpers = {
  messagesForThreadByFolder: function messagesForThreadByFolder(db, threadId) {
    return Promise.resolve(db.Thread.findById(threadId).then((thread) => {
      return thread.getMessages()
    })).then((messages) => {
      return _.groupBy(messages, "folderId")
    })
  },

  forEachMessageInThread: function forEachMessageInThread({threadId, db, imap, callback}) {
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

  openMessageBox: function openMessageBox({messageId, db, imap}) {
    return Promise.resolve(db.Message.findById(messageId).then((message) => {
      return db.Folder.findById(message.folderId).then((category) => {
        return imap.openBox(category.name).then((box) => {
          return Promise.resolve({box, message})
        })
      })
    }))
  },
}
module.exports = TaskHelpers
