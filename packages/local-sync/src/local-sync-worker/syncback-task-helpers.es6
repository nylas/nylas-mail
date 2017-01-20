const SyncbackTaskFactory = require('./syncback-task-factory');


// TODO NOTE! These are the tasks we exclude from the sync loop. This should be
// refactored later.
export const SendTaskTypes = ['SendMessage', 'SendMessagePerRecipient']

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
  *
  * TODO NOTE: This function excludes Send tasks because these are run outside fo the
  * sync loop for performance reasons.
  */
export async function getNewSyncbackTasks({db, account} = {}) {
  const {SyncbackRequest, Message} = db;

  const ensureSentFolderTasks = await SyncbackRequest.findAll({
    limit: 100,
    where: {type: ['EnsureMessageInSentFolder'], status: 'NEW'},
    order: [['createdAt', 'ASC']],
  })
  .map((req) => SyncbackTaskFactory.create(account, req))
  const tasks = await SyncbackRequest.findAll({
    limit: 100,
    where: {type: {$notIn: [...SendTaskTypes, 'EnsureMessageInSentFolder']}, status: 'NEW'},
    order: [['createdAt', 'ASC']],
  })
  .map((req) => SyncbackTaskFactory.create(account, req))

  if (ensureSentFolderTasks.length === 0 && tasks.length === 0) { return [] }

  const tasksToProcess = [
    ...ensureSentFolderTasks,
    ...tasks.filter(t => !t.affectsImapMessageUIDs()),
  ]
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

export async function markInProgressTasksAsFailed({db} = {}) {
  // We use a very limited type of two-phase commit: before we start
  // running a syncback task, we mark it as "in progress". If something
  // happens during the syncback (the worker window crashes, or the power
  // goes down), the task won't succeed or fail.
  // We absolutely never want to retry such a task, so we mark it as failed
  // at the next sync iteration. We use this function for that.
  const {SyncbackRequest} = db;
  const inProgressTasks = await SyncbackRequest.findAll({
    // TODO this is a hack
    // NOTE: We exclude SendTaskTypes because they are run outside of the sync loop
    where: {type: {$notIn: SendTaskTypes}, status: 'INPROGRESS'},
  });

  for (const inProgress of inProgressTasks) {
    inProgress.status = 'FAILED';
    await inProgress.save();
  }
}

// TODO JUAN! remove this uglyness that is runTask
export async function runSyncbackTask({task, runTask} = {}) {
  const before = new Date();
  const syncbackRequest = task.syncbackRequestObject();
  console.log(`🔃 📤 ${task.description()}`, syncbackRequest.props)
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
    console.log(`🔃 📤 ${task.description()} Succeeded (${after.getTime() - before.getTime()}ms)`)
  } catch (error) {
    syncbackRequest.error = error;
    syncbackRequest.status = "FAILED";
    const after = new Date();
    console.error(`🔃 📤 ${task.description()} Failed (${after.getTime() - before.getTime()}ms)`, {syncbackRequest: syncbackRequest.toJSON(), error})
  } finally {
    await syncbackRequest.save();
  }
}
