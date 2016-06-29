const TaskHelpers = {
  messagesForThreadByCategory: function messagesForThreadByCategory(db, threadId) {
    const msgsInCategories = {};

    return db.Thread.findById(threadId).then((thread) =>
      thread.getMessages().each((message) => {
        if (!msgsInCategories[message.CategoryId]) {
          msgsInCategories[message.CategoryId] = [message];
        } else {
          msgsInCategories.push(message);
        }
      })
    ).then(() => msgsInCategories)
  },

  forEachMessageInThread: function forEachMessageInThread({threadId, db, imap, callback}) {
    console.log("FOR EACH MESSAGE IN THREAD")
    return TaskHelpers.messagesForThreadByCategory(db, threadId)
    .then((msgsInCategories) => {
      const cids = Object.keys(msgsInCategories);
      console.log(`Messages in categories: ${cids}`)
      return db.Category.findAll({where: {id: cids}})
      .each((category) =>
        imap.openBox(category.name).then(() => {
          console.log(`Category Box open: ${category.id} | ${category.name}`);
          Promise.all(msgsInCategories[category.id].map((message) =>
            callback({message, category})
          )).then(() => imap.closeBoxAsync())
        })
      )
    })
  },
}
module.exports = TaskHelpers
