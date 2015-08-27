_ = require 'underscore'
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
    @_waiting = []
    @listenTo DatabaseStore, @_onChange

    DatabaseStore.findJSONObject(TaskQueue.JSONObjectStorageKey).then (json) =>
      @_queue = json || []
      @trigger()

  _onChange: (change) =>
    if change.objectClass is 'JSONObject' and change.objects[0].key is 'task-queue'
      @_queue = change.objects[0].json
      @_waiting = @_waiting.filter ({taskId, resolve}) =>
        task = _.findWhere(@_queue, {id: taskId})
        if not task or task.queueState.localComplete
          resolve()
          return false
        return true
      @trigger()

  queue: ->
    @_queue

  waitForPerformLocal: (task) ->
    new Promise (resolve, reject) =>
      @_waiting.push({taskId: task.id, resolve: resolve})

module.exports = new TaskQueueStatusStore()
