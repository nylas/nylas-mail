/**
 * Given a `SyncbackRequestObject` it creates the appropriate syncback task.
 *
 */
class SyncbackTaskFactory {
  static create(account, syncbackRequest) {
    let Task = null;
    switch (syncbackRequest.type) {
      case "MoveThreadToFolder":
        Task = require('./syncback_tasks/move-thread-to-folder.imap'); break;
      case "SetThreadLabels":
        Task = require('./syncback_tasks/set-thread-labels.imap'); break;
      case "MarkThreadAsRead":
        Task = require('./syncback_tasks/mark-thread-as-read.imap'); break;
      case "MarkThreadAsUnread":
        Task = require('./syncback_tasks/mark-thread-as-unread.imap'); break;
      case "StarThread":
        Task = require('./syncback_tasks/star-thread.imap'); break;
      case "UnstarThread":
        Task = require('./syncback_tasks/unstar-thread.imap'); break;
      case "MoveMessageToFolder":
        Task = require('./syncback_tasks/move-message-to-folder.imap'); break;
      case "SetMessageLabels":
        Task = require('./syncback_tasks/set-message-labels.imap'); break;
      case "MarkMessageAsRead":
        Task = require('./syncback_tasks/mark-message-as-read.imap'); break;
      case "MarkMessageAsUnread":
        Task = require('./syncback_tasks/mark-message-as-unread.imap'); break;
      case "StarMessage":
        Task = require('./syncback_tasks/star-message.imap'); break;
      case "UnstarMessage":
        Task = require('./syncback_tasks/unstar-message.imap'); break;
      case "CreateFolder":
        Task = require('./syncback_tasks/create-folder.imap'); break;
      case "RenameFolder":
        Task = require('./syncback_tasks/rename-folder.imap'); break;
      case "DeleteFolder":
        Task = require('./syncback_tasks/delete-folder.imap'); break;
      default:
        throw new Error(`Invalid Task Type: ${syncbackRequest.type}`)
    }
    return new Task(account, syncbackRequest)
  }
}

module.exports = SyncbackTaskFactory
