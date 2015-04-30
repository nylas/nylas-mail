_ = require 'underscore-plus'
fs = require 'fs-plus'
path = require 'path'
{generateTempId} = require '../models/utils'

Task = require "../tasks/task"
Reflux = require 'reflux'
Actions = require '../actions'

{APIError,
 OfflineError,
 TimeoutError} = require '../errors'

if not atom.isMainWindow() and not atom.inSpecMode() then return

module.exports =
TaskQueue = Reflux.createStore
  init: ->
    @_queue = []
    @_completed = []

    @_restoreQueueFromDisk()

    @listenTo(Actions.queueTask,              @enqueue)
    @listenTo(Actions.dequeueTask,            @dequeue)
    @listenTo(Actions.dequeueAllTasks,        @dequeueAll)
    @listenTo(Actions.logout,                 @dequeueAll)
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

  _initializeTask: (task) ->
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

  enqueue: (task, {silent}={}) ->
    if not (task instanceof Task)
      throw new Error("You must queue a `Task` object")

    @_initializeTask(task)
    @_dequeueObsoleteTasks(task)
    @_queue.push(task)
    @_update() if not silent

  dequeue: (taskOrId={}, {silent}={}) ->
    task = @_parseArgs(taskOrId)

    task.queueState.isProcessing = false
    task.cleanup()

    @_queue.splice(@_queue.indexOf(task), 1)
    @_moveToCompleted(task)
    @_update() if not silent

  dequeueAll: ->
    for task in @_queue by -1
      @dequeue(task, silent: true) if task?
    @_update()

  dequeueMatching: (task) ->
    identifier = task.matchKey
    propValue  = task.matchValue

    for other in @_queue by -1
      if task.object == task.object
        if other[identifier] == propValue
          @dequeue(other, silent: true)

    @_update()

  clearCompleted: ->
    @_completed = []
    @trigger()

  _processQueue: ->
    for task in @_queue by -1
      @_processTask(task) if task?

  _processTask: (task) ->
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

  _performRemote: (task) ->
    if @_isOnline()
      task.queueState.remoteAttempts += 1
      task.performRemote().then =>
        task.queueState.performedRemote = Date.now()
        @dequeue(task)
      .catch @_onRemoteError(task)
    else
      @_notifyOffline(task)

  _update: ->
    @trigger()
    @_saveQueueToDisk()
    @_processQueue()

  _dequeueObsoleteTasks: (task) ->
    for otherTask in @_queue by -1
      # Do not interrupt tasks which are currently processing
      continue if otherTask.queueState.isProcessing
      # Do not remove ourselves from the queue
      continue if otherTask is task
      # Dequeue tasks which our new task indicates it makes obsolete
      if task.shouldDequeueOtherTask(otherTask)
        @dequeue(otherTask, silent: true)

  _taskIsBlocked: (task) ->
    _.any @_queue, (otherTask) ->
      task.shouldWaitForTask(otherTask) and task isnt otherTask

  _notifyOffline: (task) ->
    task.queueState.isProcessing = false
    if not task.queueState.notifiedOffline
      task.queueState.notifiedOffline = true
      task.onError(new OfflineError)

  _onLocalError: (task) -> (error) =>
    task.queueState.isProcessing = false
    task.queueState.localError = error
    task.onError(error)
    @dequeue(task)

  _onRemoteError: (task) -> (apiError) =>
    task.queueState.isProcessing = false
    task.queueState.notifiedOffline = false
    task.queueState.remoteError = apiError
    task.onError(apiError)
    @dequeue(task)

  _isOnline: -> @_onlineStatus # TODO # OnlineStatusStore.isOnline()
  _onOnlineChange: -> @_processQueue()

  _parseArgs: (taskOrId) ->
    if taskOrId instanceof Task
      task = _.find @_queue, (task) -> task is taskOrId
    else
      task = _.findWhere(@_queue, id: taskOrId)
    if not task?
      throw new Error("Can't find task #{taskOrId}")
    return task

  _moveToCompleted: (task) ->
    @_completed.push(task)
    @_completed.shift() if @_completed.length > 1000

  _restoreQueueFromDisk: ->
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

  _saveQueueToDisk: (callback) ->
    queueFile = path.join(atom.getConfigDirPath(), 'task-queue.json')
    queueJSON = JSON.stringify((@_queue ? []))
    fs.writeFile(queueFile, queueJSON, callback)
