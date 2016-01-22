_ = require 'underscore'
Rx = require 'rx-lite'
NylasStore = require 'nylas-store'
DatabaseStore = require './database-store'
AccountStore = require './account-store'
TaskQueue = require './task-queue'

# Public: The TaskQueueStatusStore allows you to inspect the task queue from
# any window, even though the queue itself only runs in the work window.
#
class TaskQueueStatusStore extends NylasStore

  constructor: ->
    @_queue = []
    @_waitingLocals = []
    @_waitingRemotes = []

    query = DatabaseStore.findJSONBlob(TaskQueue.JSONBlobStorageKey)
    Rx.Observable.fromQuery(query).subscribe (json) =>
      @_queue = json || []
      @_waitingLocals = @_waitingLocals.filter ({taskId, resolve}) =>
        task = _.findWhere(@_queue, {id: taskId})
        if not task or task.queueState.localComplete
          resolve()
          return false
        return true
      @_waitingRemotes = @_waitingRemotes.filter ({taskId, resolve}) =>
        task = _.findWhere(@_queue, {id: taskId})
        if not task
          resolve()
          return false
        return true
      @trigger()

  queue: ->
    @_queue

  waitForPerformLocal: (task) =>
    new Promise (resolve, reject) =>
      @_waitingLocals.push({taskId: task.id, resolve: resolve})

  waitForPerformRemote: (task) =>
    new Promise (resolve, reject) =>
      @_waitingRemotes.push({taskId: task.id, resolve: resolve})

  tasksMatching: (type, matching = {}) ->
    type = type.name unless _.isString(type)
    @_queue.filter (task) -> task.constructor.name is type and _.isMatch(task, matching)

module.exports = new TaskQueueStatusStore()
