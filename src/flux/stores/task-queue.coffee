_ = require 'underscore-plus'
fs = require 'fs-plus'
path = require 'path'
{generateTempId} = require '../models/utils'

{Listener, Publisher} = require '../modules/reflux-coffee'
CoffeeHelpers = require '../coffee-helpers'

Task = require "../tasks/task"
Reflux = require 'reflux'
Actions = require '../actions'

{APIError,
 OfflineError,
 TimeoutError} = require '../errors'

if not atom.isMainWindow() and not atom.inSpecMode() then return

###
Public: The TaskQueue is a Flux-compatible Store that manages a queue of {Task}
objects. Each {Task} represents an individual API action, like sending a draft
or marking a thread as "read". Tasks optimistically make changes to the app's
local cache and encapsulate logic for performing changes on the server, rolling
back in case of failure, and waiting on dependent tasks.

The TaskQueue is essential to offline mode in Nylas Mail. It automatically pauses
when the user's internet connection is unavailable and resumes when online.

The task queue is persisted to disk, ensuring that tasks are executed later,
even if the user quits Nylas Mail.

The TaskQueue is only available in the app's main window. Rather than directly
queuing tasks, you should use the {Actions} to interact with the {TaskQueue}.
Tasks queued from secondary windows are serialized and sent to the application's
main window via IPC.

## Queueing a Task

```coffee
if @_thread && @_thread.isUnread()
  Actions.queueTask(new MarkThreadReadTask(@_thread))
```

## Dequeueing a Task

```coffee
Actions.dequeueMatchingTask({
  object: 'FileUploadTask',
  matchKey: "filePath"
  matchValue: uploadData.filePath
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

    @_restoreQueueFromDisk()

    @listenTo(Actions.queueTask,              @enqueue)
    @listenTo(Actions.dequeueTask,            @dequeue)
    @listenTo(Actions.dequeueAllTasks,        @dequeueAll)
    @listenTo(Actions.dequeueMatchingTask,    @dequeueMatching)

    @listenTo(Actions.clearDeveloperConsole,  @clearCompleted)

    # TODO
    # @listenTo(OnlineStatusStore, @_onOnlineChange)
    @_onlineStatus = true
    @listenTo Actions.longPollConnected, =>
      @_onlineStatus = true
      @_update()
    @listenTo Actions.longPollOffline, =>
      @_onlineStatus = false
      @_update()

  _initializeTask: (task) =>
    task.id ?= generateTempId()
    task.queueState ?= {}
    task.queueState =
      localError: null
      remoteError: null
      isProcessing: false
      remoteAttempts: 0
      performedLocal: false
      performedRemote: false
      notifiedOffline: false

  queue: =>
    @_queue

  findTask: ({object, matchKey, matchValue}) ->
    for other in @_queue by -1
      if object is object and other[matchKey] is matchValue
        return other
    return null

  enqueue: (task, {silent}={}) =>
    if not (task instanceof Task)
      throw new Error("You must queue a `Task` object")

    @_initializeTask(task)
    @_dequeueObsoleteTasks(task)
    @_queue.push(task)
    @_update() if not silent

  dequeue: (taskOrId={}, {silent}={}) =>
    task = @_parseArgs(taskOrId)
    if not task
      throw new Error("Couldn't find task in queue to dequeue")

    task.queueState.isProcessing = false
    task.cleanup()

    @_queue.splice(@_queue.indexOf(task), 1)
    @_moveToCompleted(task)
    @_update() if not silent

  dequeueAll: =>
    for task in @_queue by -1
      @dequeue(task, silent: true) if task?
    @_update()

  dequeueMatching: (task) =>
    toDequeue = @findTask(task)

    if not toDequeue
      console.warn("Could not find task: #{task?.object}", task)

    @dequeue(toDequeue, silent: true)
    @_update()

  clearCompleted: =>
    @_completed = []
    @trigger()

  _processQueue: =>
    for task in @_queue by -1
      @_processTask(task) if task?

  _processTask: (task) =>
    return if task.queueState.isProcessing
    return if @_taskIsBlocked(task)

    task.queueState.isProcessing = true

    if task.queueState.performedLocal
      @_performRemote(task)
    else
      task.performLocal().then =>
        task.queueState.performedLocal = Date.now()
        @_performRemote(task)
      .catch @_onLocalError(task)

  _performRemote: (task) =>
    if @_isOnline()
      task.queueState.remoteAttempts += 1
      task.performRemote().then =>
        task.queueState.performedRemote = Date.now()
        @dequeue(task)
      .catch @_onRemoteError(task)
    else
      @_notifyOffline(task)

  _update: =>
    @trigger()
    @_saveQueueToDiskDebounced()
    @_processQueue()

  _dequeueObsoleteTasks: (task) =>
    for otherTask in @_queue by -1
      # Do not interrupt tasks which are currently processing
      continue if otherTask.queueState.isProcessing
      # Do not remove ourselves from the queue
      continue if otherTask is task
      # Dequeue tasks which our new task indicates it makes obsolete
      if task.shouldDequeueOtherTask(otherTask)
        @dequeue(otherTask, silent: true)

  _taskIsBlocked: (task) =>
    _.any @_queue, (otherTask) ->
      task.shouldWaitForTask(otherTask) and task isnt otherTask

  _notifyOffline: (task) =>
    task.queueState.isProcessing = false
    if not task.queueState.notifiedOffline
      task.queueState.notifiedOffline = true
      task.onError(new OfflineError)

  _onLocalError: (task) => (error) =>
    task.queueState.isProcessing = false
    task.queueState.localError = error
    task.onError(error)
    @dequeue(task)

  _onRemoteError: (task) => (apiError) =>
    task.queueState.isProcessing = false
    task.queueState.notifiedOffline = false
    task.queueState.remoteError = apiError
    task.onError(apiError)
    @dequeue(task)

  _isOnline: => @_onlineStatus # TODO # OnlineStatusStore.isOnline()
  _onOnlineChange: => @_processQueue()

  _parseArgs: (taskOrId) =>
    if taskOrId instanceof Task
      task = _.find @_queue, (task) -> task is taskOrId
    else
      task = _.findWhere(@_queue, id: taskOrId)
    return task

  _moveToCompleted: (task) =>
    @_completed.push(task)
    @_completed.shift() if @_completed.length > 1000

  _restoreQueueFromDisk: =>
    {modelReviver} = require '../models/utils'
    try
      queueFile = path.join(atom.getConfigDirPath(), 'task-queue.json')
      queue = JSON.parse(fs.readFileSync(queueFile), modelReviver)
      # We need to set the processing bit back to false so it gets
      # re-retried upon inflation
      for task in queue
        if task.queueState?.isProcessing
          task.queueState ?= {}
          task.queueState.isProcessing = false
      @_queue = queue
    catch e
      if not atom.inSpecMode()
        console.log("Queue deserialization failed with error: #{e.toString()}")

  # It's very important that we debounce saving here. When the user bulk-archives
  # items, they can easily process 1000 tasks at the same moment. We can't try to
  # save 1000 times! (Do not remove debounce without a plan!)

  _saveQueueToDisk: =>
    queueFile = path.join(atom.getConfigDirPath(), 'task-queue.json')
    queueJSON = JSON.stringify((@_queue ? []))
    fs.writeFile(queueFile, queueJSON)

  _saveQueueToDiskDebounced: =>
    @__saveQueueToDiskDebounced ?= _.debounce(@_saveQueueToDisk, 150)
    @__saveQueueToDiskDebounced()

module.exports = new TaskQueue()
