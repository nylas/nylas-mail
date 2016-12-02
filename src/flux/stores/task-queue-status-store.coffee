_ = require 'underscore'
Rx = require 'rx-lite'
NylasStore = require 'nylas-store'
DatabaseStore = require('./database-store').default
AccountStore = require('./account-store').default
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
      @_waitingLocals = @_waitingLocals.filter ({task, resolve}) =>
        queuedTask = _.findWhere(@_queue, {id: task.id})
        if not queuedTask or queuedTask.queueState.localComplete
          resolve(task)
          return false
        return true
      @_waitingRemotes = @_waitingRemotes.filter ({task, resolve}) =>
        queuedTask = _.findWhere(@_queue, {id: task.id})
        if not queuedTask
          resolve(task)
          return false
        return true
      @trigger()

  queue: ->
    @_queue

  waitForPerformLocal: (task) =>
    new Promise (resolve, reject) =>
      @_waitingLocals.push({task, resolve})

  waitForPerformRemote: (task) =>
    new Promise (resolve, reject) =>
      @_waitingRemotes.push({task, resolve})

  tasksMatching: (type, matching = {}) ->
    type = type.name unless _.isString(type)
    @_queue.filter (task) -> task.constructor.name is type and _.isMatch(task, matching)

module.exports = new TaskQueueStatusStore()
