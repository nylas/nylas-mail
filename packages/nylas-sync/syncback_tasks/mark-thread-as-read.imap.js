class MarkThreadAsRead {
  constructor(account, syncbackRequest) {
    this._account = account;
    this._syncbackRequest = syncbackRequest;
  }

  description() {
    return `MarkThreadAsRead`;
  }

  run(db, imap) {
    const {Category, Thread} = db;
    const thread = Thread.findById(this._syncbackRequest.threadId);
    const msgsInCategories = {};

    thread.getMessages((messages) => {
      for (const message of messages) {
        if (!msgsInCategories[messages.CategoryId]) {
          msgsInCategories[messages.CategoryId] = [message.messageId];
        } else {
          msgsInCategories.push(message.messageId);
        }
      }
      for (const categoryId of Object.keys(msgsInCategories)) {
        Category.findById(categoryId).then((category) => {
          imap.openBox(category, false);
          for (const messageId of msgsInCategories[categoryId]) {
            imap.addFlags(messageId, 'Seen', (err) => { throw err; });
          }
          imap.closeBox();
        })
      }
    })
  }
}
module.exports = MarkThreadAsRead;
