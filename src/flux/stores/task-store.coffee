Task = "../tasks/task"
Reflux = require 'reflux'
Actions = require '../actions'
{modelReviver} = require '../models/utils'
_ = require 'underscore-plus'
path = require 'path'
fs = require 'fs-plus'

# The TaskStore listens for the queueTask action, performs tasks
# locally, and queues them for running against the API. In the
# future, it will be responsible for serializing the queue, doing
# dependency resolution, and marshalling recovery from errors.

if atom.state.mode is "composer" then return

MAX_RETRIES = 3

module.exports =
TaskStore = Reflux.createStore
  init: ->
    @_setDefaults()
    try
      queueFile = path.join(atom.getConfigDirPath(), 'task-queue.json')
      @_queue = JSON.parse(fs.readFileSync(queueFile), modelReviver)
    catch e
      console.log("Queue deserialization failed with error: #{e.toString()}")

    @listenTo(Actions.resetTaskQueue, @reset)
    @listenTo(Actions.queueTask, @_onQueueTask)
    @listenTo(Actions.abortTask, @_onAbortTask)
    @listenTo(Actions.restartTaskQueue, @_onUnpause)
    @listenTo(Actions.logout, @_onLogout)
    @performNextTask()

  # Finds tasks whose JSON form matches `criteria` and removes them from
  # the queue. If the tasks are `pending` it will call `abort` on the task
  # object, followed by `rollbackLocal`
  _onAbortTask: (criteria, options={abort:true, rollbackLocal: true}) ->
    matchFunc = (item) -> _.matches(criteria)(item.toJSON())

    matchingQueuedTasks = _.filter(@_queue, matchFunc)
    matchingPendingTasks = _.filter(@_pending, matchFunc)

    for queuedTask in matchingQueuedTasks
      queuedTask.rollbackLocal() if options.rollbackLocal
      queuedTask.cleanup()
    @_queue = _.difference @_queue, matchingQueuedTasks

    for pendingTask in matchingPendingTasks
      pendingTask.abort() if options.abort
      pendingTask.rollbackLocal() if options.rollbackLocal
      pendingTask.cleanup()
    @_pending = _.difference @_pending, matchingPendingTasks

    @trigger()
    @persist =>
      @performNextTask()

  _setDefaults: ->
    @_queue = []
    @_pending = []
    @_paused = false
    @trigger()

  reset: ->
    @_setDefaults()
    @persist()

  _onLogout: ->
    @reset()
    @persist()

  _onUnpause: ->
    return unless @_paused
    @_paused = false
    @trigger()
    @performNextTask()

  _onQueueTask: (task) ->
    @_queue = _.reject @_queue, (other) ->
      task.shouldCancelUnstartedTask(other)
    @trigger()
    @_pending.push(task)

    finish = =>
      @_pending.splice(@_pending.indexOf(task), 1)
      @trigger()
      @persist =>
        @performNextTask()

    task.performLocal()
    .then =>
      @_queue.push(task)
      finish()
    .catch (error) =>
      @_displayError("PerformLocal failed on #{task.constructor.name}. It will not be performed remotely.", error.message, error)
      finish()

  persist: (callback) ->
    queueFile = path.join(atom.getConfigDirPath(), 'task-queue.json')
    queueJSON = JSON.stringify([].concat(@_queue).concat(@_pending))
    fs.writeFile(queueFile, queueJSON, callback)

  queuedTasks: ->
    @_queue

  pendingTasks: ->
    @_pending

  isPaused: ->
    @_paused

  canPerformTask: (task) ->
    for other in [].concat(@_pending, @_queue)
      if other != task && task.shouldWaitForTask(other)
        return false
    true

  performNextTask: ->
    return Promise.resolve("Queue paused") if @_paused

    task = _.find(@_queue, @canPerformTask.bind(@))
    return Promise.resolve("Nothing to do") unless task

    new Promise (resolve, reject) =>
      @_queue.splice(@_queue.indexOf(task), 1)
      @_pending.push(task)
      @trigger()

      finished = =>
        task.cleanup()
        @_pending.splice(@_pending.indexOf(task), 1)
        @trigger()
        @persist =>
          @performNextTask()
        resolve()

      task.performRemote()
      .then ->
        finished()
      .catch (error) =>
        @_displayError(error)
        if task.shouldRetry(error) and task.retryCount < MAX_RETRIES
          task.retryCount += 1
          @_queue.push(task)
        else
          task.rollbackLocal()
        finished()

  _displayError: (args...) ->
    console.error(args...)
