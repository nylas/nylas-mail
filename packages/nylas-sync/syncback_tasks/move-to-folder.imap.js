const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')

class MoveToFolderIMAP extends SyncbackTask {
  description() {
    return `MoveToFolder`;
  }

  run(db, imap) {
    console.log("------------------ RUNNING MOVE TO FOLDER IMAP")
    const threadId = this.syncbackRequestObject().props.threadId
    const toFolderId = this.syncbackRequestObject().props.folderId

    const eachMsg = (message) => {
      console.log(`For message ${message.id}. Moving`)
      return imap.moveAsync(message.messageId, toFolderId)
    }

    return TaskHelpers.forEachMessageInThread({threadId, db, imap, callback: eachMsg})

    // for (const {message, category} of msgGenerator) {
    //   imap.moveAsync(messageId)
    // }
    // const {Category, Thread} = db;
    // const threadId = this.syncbackRequestObject().props.threadId
    // const toFolderId = this.syncbackRequestObject().props.folderId
    //
    // const thread = Thread.findById(threadId);
    // const toFolder = Category.findById(toFolderId);
    //
    // const msgsInCategories = {};
    //
    // thread.getMessages((messages) => {
    //   for (const message of messages) {
    //     if (!msgsInCategories[message.CategoryId]) {
    //       msgsInCategories[message.CategoryId] = [message.messageId];
    //     } else {
    //       msgsInCategories.push(message.messageId);
    //     }
    //   }
    //   for (const categoryId of Object.keys(msgsInCategories)) {
    //     Category.findById(categoryId).then((category) => {
    //       imap.openBox(category, false);
    //       for (const messageId of msgsInCategories[categoryId]) {
    //         imap.moveAsync(messageId, toCategoryName);
    //       }
    //       imap.closeBox();
    //     })
    //   }
    // })
  }
}
module.exports = MoveToFolderIMAP
