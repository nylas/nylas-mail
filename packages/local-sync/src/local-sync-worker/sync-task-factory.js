/* eslint global-require: 0 */
class SyncTaskFactory {

  static create(taskName, ...args) {
    let Task = null;
    switch (taskName) {
      case "FetchFolderList":
        Task = require('./sync-tasks/fetch-folder-list.imap'); break;
      case "FetchMessagesInFolder":
        Task = require('./sync-tasks/fetch-messages-in-folder.imap'); break;
      case "FetchNewMessagesInFolder":
        Task = require('./sync-tasks/fetch-new-messages-in-folder.imap'); break;
      default:
        throw new Error(`Task type not defined in syncback--factory: ${taskName}`)
    }
    return new Task(...args)
  }
}

module.exports = SyncTaskFactory
