const {Actions} = require('nylas-exports')
const {IMAPErrors} = require('isomorphic-core')
const SyncbackTaskFactory = require('./syncback-task-factory');

const MAX_TASK_RETRIES = 2

const SendTaskTypes = [
  'SendMessage',
  'SendMessagePerRecipient',
  'EnsureMessageInSentFolder',
]

class SyncbackTaskRunner {

  constructor({db, account, logger} = {}) {
    if (!db) {
      throw new Error('SyncbackTaskRunner: need to pass db')
    }
    if (!account) {
      throw new Error('SyncbackTaskRunner: need to pass account')
    }
    if (!logger) {
      throw new Error('SyncbackTaskRunner: need to pass logger')
    }
    this._db = db
    this._account = account
    this._logger = logger
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
  async getNewSyncbackTasks() {
    const {SyncbackRequest, Message} = this._db;

    const sendTasks = await SyncbackRequest.findAll({
      limit: 100,
      where: {type: SendTaskTypes, status: 'NEW'},
      order: [['createdAt', 'ASC']],
    })
    .map((req) => SyncbackTaskFactory.create(this._account, req))
    const otherTasks = await SyncbackRequest.findAll({
      limit: 100,
      where: {type: {$notIn: SendTaskTypes}, status: 'NEW'},
      order: [['createdAt', 'ASC']],
    })
    .map((req) => SyncbackTaskFactory.create(this._account, req))

    if (sendTasks.length === 0 && otherTasks.length === 0) { return [] }

    const tasksToProcess = [
      ...sendTasks,
      ...otherTasks.filter(t => !t.affectsImapMessageUIDs()),
    ]
    const tasksAffectingUIDs = otherTasks.filter(t => t.affectsImapMessageUIDs())

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

  async markInProgressTasksAsFailed() {
    // We use a very limited type of two-phase commit: before we start
    // running a syncback task, we mark it as "in progress". If something
    // happens during the syncback (the worker window crashes, or the power
    // goes down), the task won't succeed or fail.
    // We absolutely never want to retry such a task, so we mark it as failed
    // at the next sync iteration. We use this function for that.
    const {SyncbackRequest} = this._db;
    const inProgressTasks = await SyncbackRequest.findAll({
      where: {status: 'INPROGRESS'},
    });

    for (const inProgress of inProgressTasks) {
      inProgress.status = 'FAILED';
      inProgress.error = new Error('Lingering task in progress was marked as failed')
      await inProgress.save();
    }
  }

  // TODO JUAN! remove this uglyness that is runTask
  async runSyncbackTask({task, runTask} = {}) {
    const before = new Date();
    const syncbackRequest = task.syncbackRequestObject();
    let shouldRetry = false

    this._logger.log(`🔃 📤 ${task.description()}`, syncbackRequest.props)
    try {
      // Before anything, mark the task as in progress. This allows
      // us to not run the same task twice.
      syncbackRequest.status = "INPROGRESS";
      await syncbackRequest.save();

      // TODO `runTask` is a hack to allow tasks to be executed outside the
      // context of an imap connection, specifically to allow running send tasks
      // outside of the sync loop. This should be solved in a better way or
      // probably refactored when we implement the sync scheduler
      const responseJSON = await runTask(task)
      syncbackRequest.status = "SUCCEEDED";
      syncbackRequest.responseJSON = responseJSON || {};

      const after = new Date();
      this._logger.log(`🔃 📤 ${task.description()} Succeeded (${after.getTime() - before.getTime()}ms)`)
    } catch (error) {
      const after = new Date();
      const {numRetries = 0} = syncbackRequest.props

      if (error instanceof IMAPErrors.RetryableError && numRetries < MAX_TASK_RETRIES) {
        Actions.recordUserEvent('Retrying syncback task', {numRetries})
        shouldRetry = true
        // We save this in `props` to avoid a db migration
        syncbackRequest.props = Object.assign({}, syncbackRequest.props, {
          numRetries: numRetries + 1,
        })
        syncbackRequest.status = "NEW";
        this._logger.warn(`🔃 📤 ${task.description()} Failed with retryable error, retrying in next loop (${after.getTime() - before.getTime()}ms)`, {syncbackRequest: syncbackRequest.toJSON(), error})
      } else {
        error.message = `Syncback Task Failed: ${error.message}`
        syncbackRequest.error = error;
        syncbackRequest.status = "FAILED";
        NylasEnv.reportError(error);
        this._logger.error(`🔃 📤 ${task.description()} Failed (${after.getTime() - before.getTime()}ms)`, {syncbackRequest: syncbackRequest.toJSON(), error})
      }
    } finally {
      await syncbackRequest.save();
    }
    return {shouldRetry}
  }
}

export default SyncbackTaskRunner
