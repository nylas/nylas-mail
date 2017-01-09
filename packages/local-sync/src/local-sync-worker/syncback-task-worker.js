const {
  IMAPConnection,
} = require('isomorphic-core');
const SyncbackTaskFactory = require('./syncback-task-factory')


/**
 * SyncbackTaskWorker runs newly available syncback requests
 */
class SyncbackTaskWorker {

  constructor(account, db) {
    if (!account) {
      throw new Error('SyncbackTaskWorker requires an account')
    }
    if (!db) {
      throw new Error('SyncbackTaskWorker requires a db instance')
    }
    this._account = account
    this._db = db
  }

  /**
   * Returns a list of at most 100 Syncback requests, sorted by creation date
   * (older first) and by how they affect message IMAP uids.
   *
   * We want to make sure that we run the tasks that affect IMAP uids last, and
   * that we don't  run 2 tasks that will affect the same set of UIDS together,
   * i.e. without running a sync loop in between them.
   *
   * For example, if there's a task to change the labels of a message, and also
   * a task to move that message to another folder, we need to run the label
   * change /first/, otherwise the message would be moved and it would receive a
   * new IMAP uid, and then attempting to change labels with an old uid would
   * fail.
   */
  async _getNewSyncbackTasks() {
    const {SyncbackRequest, Message} = this._db;
    const where = {
      limit: 100,
      where: {status: "NEW"},
      order: [['createdAt', 'ASC']],
    };

    const tasks = await SyncbackRequest.findAll(where)
    .map((req) => SyncbackTaskFactory.create(this._account, req))

    if (tasks.length === 0) { return [] }

    // TODO prioritize Send!

    const tasksToProcess = tasks.filter(t => !t.affectsImapMessageUIDs())
    const tasksAffectingUIDs = tasks.filter(t => t.affectsImapMessageUIDs())

    const changeFolderTasks = tasksAffectingUIDs.filter(t =>
      t.description() === 'RenameFolder' || t.description() === 'DeleteFolder'
    )
    if (changeFolderTasks.length > 0) {
      // If we are renaming or deleting folders, those are the only tasks we
      // want to process before executing any other tasks that may change uids.
      // These operations may not change the uids of their messages, but we
      // can't guarantee it, so to make sure, we will just run these.
      const affectedFolderIds = new Set()
      changeFolderTasks.forEach((task) => {
        const {props: {folderId}} = task.syncbackRequestObject()
        if (folderId && !affectedFolderIds.has(folderId)) {
          tasksToProcess.push(task)
          affectedFolderIds.add(folderId)
        }
      })
      return tasksToProcess
    }

    // Otherwise, make sure that we don't process more than 1 task that will affect
    // the UID of the same message
    const affectedMessageIds = new Set()
    for (const task of tasksAffectingUIDs) {
      const {props: {messageId, threadId}} = task.syncbackRequestObject()
      if (messageId) {
        if (!affectedMessageIds.has(messageId)) {
          tasksToProcess.push(task)
          affectedMessageIds.add(messageId)
        }
      } else if (threadId) {
        const messageIds = await Message.findAll({where: {threadId}}).map(m => m.id)
        const shouldIncludeTask = messageIds.every(id => !affectedMessageIds.has(id))
        if (shouldIncludeTask) {
          tasksToProcess.push(task)
          messageIds.forEach(id => affectedMessageIds.add(id))
        }
      }
    }
    return tasksToProcess
  }

  async runSyncbackTask(conn, task) {
    const syncbackRequest = task.syncbackRequestObject();
    console.log(`🔃 📤 ${task.description()}`, syncbackRequest.props)
    try {
      const responseJSON = await conn.runOperation(task);
      syncbackRequest.status = "SUCCEEDED";
      syncbackRequest.responseJSON = responseJSON || {};
      console.log(`🔃 📤 ${task.description()} Succeeded`)
    } catch (error) {
      syncbackRequest.error = error;
      syncbackRequest.status = "FAILED";
      console.error(`🔃 📤 ${task.description()} Failed`, {syncbackRequest: syncbackRequest.toJSON()})
    } finally {
      await syncbackRequest.save();
    }
  }

  async runNewSyncbackTasks(conn) {
    // TODO Make this interruptible too!
    if (!(conn instanceof IMAPConnection)) {
      throw new Error('SyncbackTaskWorker requires an IMAPConnection')
    }

    const tasks = await this._getNewSyncbackTasks()
    if (tasks.length === 0) { return; }
    for (const task of tasks) {
      await this.runSyncbackTask(conn, task)
    }
  }
}

module.exports = SyncbackTaskWorker
