_ = require 'underscore'
fs = require 'fs-plus'
path = require 'path'

{Listener, Publisher} = require '../modules/reflux-coffee'
CoffeeHelpers = require '../coffee-helpers'

Task = require("../tasks/task").default
TaskRegistry = require('../../task-registry').default
Utils = require "../models/utils"
Reflux = require 'reflux'
Actions = require '../actions'
DatabaseStore = require './database-store'

{APIError,
 TimeoutError} = require '../errors'

JSONBlobStorageKey = 'task-queue'

if not NylasEnv.isWorkWindow() and not NylasEnv.inSpecMode()
  module.exports = {JSONBlobStorageKey}
  return

###
Public: The TaskQueue is a Flux-compatible Store that manages a queue of {Task}
objects. Each {Task} represents an individual API action, like sending a draft
or marking a thread as "read". Tasks optimistically make changes to the app's
local cache and encapsulate logic for performing changes on the server, rolling
back in case of failure, and waiting on dependent tasks.

The TaskQueue is essential to offline mode in N1. It automatically pauses
when the user's internet connection is unavailable and resumes when online.

The task queue is persisted to disk, ensuring that tasks are executed later,
even if the user quits N1.

The TaskQueue is only available in the app's main window. Rather than directly
queuing tasks, you should use the {Actions} to interact with the {TaskQueue}.
Tasks queued from secondary windows are serialized and sent to the application's
main window via IPC.

## Queueing a Task

```coffee
if @_thread && @_thread.unread
  Actions.queueTask(new ChangeStarredTask(thread: @_thread, starred: true))
```

## Dequeueing a Task

```coffee
Actions.dequeueMatchingTask({
  type: 'DestroyCategoryTask',
  matching: {
    categoryId: 'bla'
  }
})
```

## Creating Tasks

Support for creating custom {Task} subclasses in third-party packages is coming soon.
This is currently blocked by the ActionBridge, which is responsible for sending actions
between windows, since it's JSON serializer is not extensible.

Section: Stores
###
class TaskQueue
  @include: CoffeeHelpers.includeModule

  @include Publisher
  @include Listener

  constructor: ->
    @_queue = []
    @_completed = []
    @_updatePeriodicallyTimeout = null
    @_currentSequentialId = Date.now()

    @_restoreQueue()

    @listenTo Actions.queueTask, @enqueue
    @listenTo Actions.queueTasks, (tasks) =>
      return unless tasks and tasks.length > 0
      @enqueue(t) for t in tasks
    @listenTo Actions.undoTaskId, @enqueueUndoOfTaskId
    @listenTo Actions.dequeueTask, @dequeue
    @listenTo Actions.dequeueAllTasks, @dequeueAll
    @listenTo Actions.dequeueMatchingTask, @dequeueMatching
    @listenTo Actions.clearDeveloperConsole,  @clearCompleted

  queue: =>
    @_queue

  completed: =>
    @_completed

  allTasks: =>
    [].concat(@_queue, @_completed)

  ###
  Public: Returns an existing task in the queue that matches the type you provide,
  and any other match properties. Useful for checking to see if something, like
  a "SendDraft" task is in-flight.

  - `type`: The string name of the task class, or the Task class itself. (ie:
    {SaveDraftTask} or 'SaveDraftTask')

  - `matching`: Optional An {Object} with criteria to pass to _.isMatch. For a
     SaveDraftTask, this could be {draftClientId: "123123"}

  Returns a matching {Task}, or null.
  ###
  findTask: (type, matching = {}) ->
    @findTasks(type, matching)[0]

  findTasks: (type, matching = {}, {includeCompleted}={}) ->
    type = type.name unless _.isString(type)
    tasks = if includeCompleted then @_queue.concat(@_completed) else @_queue
    matches = _.filter tasks, (task) ->
      return false if task.constructor.name isnt type
      isMatch = false
      if _.isFunction(matching) then isMatch = matching(task)
      else isMatch = _.isMatch(task, matching)
      return isMatch
    return matches ? []

  enqueue: (task) =>
    if not (task instanceof Task)
      throw new Error("You must queue a `Task` instance. Be sure you have the task registered with the TaskRegistry. If this is a task for a custom plugin, you must export a `taskConstructors` array with your `Task` constructors in it. You must all subclass the base Nylas `Task`.")
    if not (TaskRegistry.isInRegistry(task.constructor.name))
      throw new Error("You must queue a `Task` instance which is registred with the TaskRegistry")
    if not task.id
      throw new Error("Tasks must have an ID prior to being queued. Check that your Task constructor is calling `super`")
    if not task.queueState
      throw new Error("Tasks must have a queueState prior to being queued. Check that your Task constructor is calling `super`")
    task.sequentialId = ++@_currentSequentialId

    @_dequeueObsoleteTasks(task)
    task.runLocal().then =>
      @_queue.push(task)
      @_updateSoon()

  enqueueUndoOfTaskId: (taskId) =>
    task = _.findWhere(@_queue, {id: taskId})
    task ?= _.findWhere(@_completed, {id: taskId})
    if task
      @enqueue(task.createUndoTask())

  dequeue: (taskOrId) =>
    task = @_resolveTaskArgument(taskOrId)
    if not task
      throw new Error("Couldn't find task in queue to dequeue")

    if task.queueState.isProcessing
      # We cannot remove a task from the queue while it's running and pretend
      # things have stopped. Ask the task to cancel. It's promise will resolve
      # or reject, and then we'll end up back here.
      task.cancel()
    else
      @_queue.splice(@_queue.indexOf(task), 1)
      @_completed.push(task)
      @_completed.shift() if @_completed.length > 1000
      @_updateSoon()

  dequeueTaskAndDependents: (taskOrId) ->
    task = @_resolveTaskArgument(taskOrId)
    if not task
      throw new Error("Couldn't find task in queue to dequeue")

  dequeueAll: =>
    for task in @_queue by -1
      @dequeue(task)

  dequeueMatching: ({type, matching}) =>
    task = @findTask(type, matching)

    if not task
      console.warn("Could not find matching task: #{type}", matching)
      return

    @dequeue(task)

  clearCompleted: =>
    @_completed = []
    @trigger()

  # Helper Methods

  _processQueue: =>
    started = 0

    if @_processQueueTimeout
      clearTimeout(@_processQueueTimeout)
      @_processQueueTimeout = null

    now = Date.now()
    reprocessIn = Number.MAX_VALUE

    for task in @_queue by -1
      if @_taskIsBlocked(task)
        task.queueState.debugStatus = Task.DebugStatus.WaitingOnDependency
        continue

      if task.queueState.retryAfter and task.queueState.retryAfter > now
        reprocessIn = Math.min(task.queueState.retryAfter - now, reprocessIn)
        task.queueState.debugStatus = Task.DebugStatus.WaitingToRetry
        continue

      @_processTask(task)
      started += 1

    if started > 0
      @trigger()

    if reprocessIn isnt Number.MAX_VALUE
      @_processQueueTimeout = setTimeout(@_processQueue, reprocessIn + 500)

  _processTask: (task) =>
    return if task.queueState.isProcessing

    task.queueState.isProcessing = true
    task.runRemote()
    .finally =>
      task.queueState.isProcessing = false
      @trigger()
    .then (status) =>
      if status is Task.Status.Retry
        task.queueState.retryDelay = Math.round(Math.min((task.queueState.retryDelay ? 1000) * 2, 30000))
        task.queueState.retryAfter = Date.now() + task.queueState.retryDelay
      else
        @dequeue(task)
      @_updateSoon()

    .catch (err) =>
      @_seenDownstream = {}
      @_notifyOfDependentError(task, err)
      .then (responses) =>
        @_dequeueDownstreamTasks(responses)
        @dequeue(task)

  # When we `_notifyOfDependentError`s, we collect a nested array of
  # responses of the tasks we notified. We need to responses to determine
  # whether or not we should dequeue that task.
  _dequeueDownstreamTasks: (responses=[]) ->
    # Responses are nested arrays due to the recursion
    responses = _.flatten(responses)

    # A response may be `null` if it hit our infinite recursion check.
    responses = _.filter responses, (r) -> r?

    responses.forEach (resp) =>
      resp.downstreamTask.queueState.status = Task.Status.Continue
      resp.downstreamTask.queueState.debugStatus = Task.DebugStatus.DequeuedDependency
      @dequeue(resp.downstreamTask)

  # Recursively notifies tasks of dependent errors
  _notifyOfDependentError: (failedTask, err) ->
    downstream = @_tasksToDequeueOnFailure(failedTask) ? []
    Promise.map downstream, (downstreamTask) =>

      return Promise.resolve(null) unless downstreamTask

      # Infinte recursion check!
      # These will get removed later
      return Promise.resolve(null) if @_seenDownstream[downstreamTask.id]
      @_seenDownstream[downstreamTask.id] = true

      responseHash = Promise.props
        returnValue: downstreamTask.onDependentTaskError(failedTask, err)
        downstreamTask: downstreamTask

      return Promise.all([
        responseHash
        @_notifyOfDependentError(downstreamTask, err)
      ])

  _dequeueObsoleteTasks: (task) =>
    obsolete = _.filter @_queue, (otherTask) =>
      # Do not interrupt tasks which are currently processing
      return false if otherTask.queueState.isProcessing
      # Do not remove ourselves from the queue
      return false if otherTask is task
      # Dequeue tasks which our new task indicates it makes obsolete
      return task.shouldDequeueOtherTask(otherTask)

    for otherTask in obsolete
      otherTask.queueState.status = Task.Status.Continue
      otherTask.queueState.debugStatus = Task.DebugStatus.DequeuedObsolete
      @dequeue(otherTask)

  _tasksToDequeueOnFailure: (failedTask) ->
    _.filter @_queue, (otherTask) ->
      failedTask isnt otherTask and
      otherTask.isDependentOnTask(failedTask) and
      otherTask.shouldBeDequeuedOnDependencyFailure()

  _taskIsBlocked: (task) =>
    _.any @_queue, (otherTask) ->
      task isnt otherTask and task.isDependentOnTask(otherTask)

  _resolveTaskArgument: (taskOrId) =>
    if not taskOrId
      return null
    else if taskOrId instanceof Task
      return _.find @_queue, (task) -> task is taskOrId
    else
      return _.findWhere(@_queue, id: taskOrId)

  _restoreQueue: =>
    DatabaseStore.findJSONBlob(JSONBlobStorageKey).then (queue = []) =>
      # We need to set the processing bit back to false so it gets
      # re-retried upon inflation
      for task in queue
        task.queueState ?= {}
        task.queueState.isProcessing = false
        delete task.queueState['retryAfter']
        delete task.queueState['retryDelay']

      # The Task queue is completely wrecked if an item in the queue is not a
      # task instance. This can happen if we removed or renamed the Task class,
      # or if it was not registred with the TaskRegistry properly.
      queue = queue.filter (task) => task instanceof Task

      @_queue = queue
      @_updateSoon()

  _updateSoon: =>
    @_updateSoonThrottled ?= _.throttle =>
      DatabaseStore.inTransaction (t) =>
        t.persistJSONBlob(JSONBlobStorageKey, @_queue ? [])
      _.defer =>
        @_processQueue()
        @_ensurePeriodicUpdates()
    , 10

    @_updateSoonThrottled()

  _ensurePeriodicUpdates: =>
    anyIsProcessing = _.any @_queue, (task) -> task.queueState.isProcessing

    # The task queue triggers periodically as tasks are processed, even if no
    # major events have occurred. This allows tasks which have state, like
    # SendDraftTask.progress to be propogated through the app and inspected.
    if anyIsProcessing and not @_updatePeriodicallyTimeout
      @_updatePeriodicallyTimeout = setInterval =>
        @_updateSoon()
      , 1000
    else if not anyIsProcessing and @_updatePeriodicallyTimeout
      clearTimeout(@_updatePeriodicallyTimeout)
      @_updatePeriodicallyTimeout = null

module.exports = new TaskQueue()
module.exports.JSONBlobStorageKey = JSONBlobStorageKey
