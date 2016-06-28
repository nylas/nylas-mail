/**
 * Given a `SyncbackRequestObject` it creates the appropriate syncback task.
 *
 */
class SyncbackTaskFactory {
  static create(account, syncbackRequest) {
    if (syncbackRequest.type === "MoveToFolder") {
      // TODO: Know it's IMAP from the account object.
      const Task = require('./syncback_tasks/move-to-folder.imap');
      return new Task(account, syncbackRequest)
    }
    return null
  }
}

module.exports = SyncbackTaskFactory
