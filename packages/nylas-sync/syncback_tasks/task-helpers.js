const _ = require('underscore')

const TaskHelpers = {
  messagesForThreadByCategory: function messagesForThreadByCategory(db, threadId) {
    return db.Thread.findById(threadId).then((thread) => {
      return thread.getMessages()
    }).then((messages) => {
      return _.groupBy(messages, "categoryId")
    })
  },

  forEachMessageInThread: function forEachMessageInThread({threadId, db, imap, callback}) {
    return TaskHelpers.messagesForThreadByCategory(db, threadId)
    .then((msgsInCategories) => {
      const cids = Object.keys(msgsInCategories);
      return db.Category.findAll({where: {id: cids}})
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
      return db.Category.findById(message.categoryId).then((category) => {
        return imap.openBox(category.name).then((box) => {
          return Promise.resolve({box, message})
        })
      })
    })
  },
}
module.exports = TaskHelpers
