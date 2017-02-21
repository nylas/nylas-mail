import NylasStore from 'nylas-store'
import {MetricsReporter} from 'isomorphic-core'
import Actions from '../actions'
import Utils from '../models/utils'
import TaskFactory from '../tasks/task-factory'
import IdentityStore from '../stores/identity-store'
import FocusedPerspectiveStore from '../stores/focused-perspective-store'


class ThreadListActionsStore extends NylasStore {

  constructor() {
    super()
    this._timers = new Map()
  }

  activate() {
    this.listenTo(Actions.archiveThreads, this._onArchiveThreads)
    this.listenTo(Actions.removeThreadsFromView, this._onRemoveThreadsFromView)
    this.listenTo(Actions.threadListDidUpdate, this._onThreadListDidUpdate)
  }

  deactivate() {
    this.stopListeningToAll()
  }

  _onThreadListDidUpdate = (threads) => {
    const updatedAt = Date.now()
    const identity = IdentityStore.identity()
    if (!identity) { return }

    const nylasId = identity.id
    const threadIdsInList = new Set(threads.map(t => t.id))

    for (const [timerId, timerData] of this._timers.entries()) {
      const {threadIds, source, action, accountId, targetCategory} = timerData
      const threadsHaveBeenRemoved = threadIds.every(id => !threadIdsInList.has(id))
      if (threadsHaveBeenRemoved) {
        const actionTimeMs = NylasEnv.timer.stop(timerId, updatedAt)
        MetricsReporter.reportEvent({
          action,
          source,
          nylasId,
          accountId,
          actionTimeMs,
          targetCategory,
          threadCount: threadIds.length,
        })
        this._timers.delete(timerId)
      }
    }
  }

  _setNewTimer({threads, source, action, targetCategory = 'unknown'} = {}) {
    const threadIds = threads.map(t => t.id)
    const timerId = Utils.generateTempId()
    const timerData = {
      source,
      action,
      threadIds,
      targetCategory,
      // accountId is irrelevant for metrics reporting but we need to include
      // one in order to make a NylasAPIRequest to our /ingest-metrics endpoint
      accountId: threads[0].accountId,
    }
    this._timers.set(timerId, timerData)
    NylasEnv.timer.start(timerId)
  }

  _onArchiveThreads = ({threads, source} = {}) => {
    if (threads.length === 0) { return }
    this._setNewTimer({threads, source, action: 'remove-from-view', targetCategory: 'archive'})
    const tasks = TaskFactory.tasksForArchiving({threads, source})
    Actions.queueTasks(tasks)
  }

  _onRemoveThreadsFromView = ({threads, ruleset, source} = {}) => {
    if (threads.length === 0) { return }
    const perspective = FocusedPerspectiveStore.current()
    const tasks = perspective.tasksForRemovingItems(threads, ruleset, source)

    // This action can encompass many different actions, e.g.:
    // - unstarring in starred view
    // - changing unread in unread view
    // - Moving to inbox from trash
    // - archiving a search result (which won't actually remove it from the thread-list)
    // For now, we are only interested in timing actions that remove threads
    // from the inbox
    if (perspective.isInbox()) {
      // TODO figure out the `targetCategory`
      this._setNewTimer({threads, source, action: 'remove-from-view'})
    }

    Actions.queueTasks(tasks)
  }
}

export default new ThreadListActionsStore()
