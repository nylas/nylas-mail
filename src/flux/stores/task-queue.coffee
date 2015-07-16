_ = require 'underscore'
fs = require 'fs-plus'
path = require 'path'
{generateTempId} = require '../models/utils'

{Listener, Publisher} = require '../modules/reflux-coffee'
CoffeeHelpers = require '../coffee-helpers'

Task = require "../tasks/task"
Reflux = require 'reflux'
Actions = require '../actions'

{APIError,
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
if @_thread && @_thread.unread
  Actions.queueTask(new UpdateThreadsTask([@_thread], starred: true))
```

## Dequeueing a Task

```coffee
Actions.dequeueMatchingTask({
  type: 'FileUploadTask',
  matching: {
    filePath: uploadData.filePath
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

    @_restoreQueueFromDisk()

    @listenTo(Actions.queueTask,              @enqueue)
    @listenTo(Actions.dequeueTask,            @dequeue)
    @listenTo(Actions.dequeueAllTasks,        @dequeueAll)
    @listenTo(Actions.dequeueMatchingTask,    @dequeueMatching)

    @listenTo(Actions.clearDeveloperConsole,  @clearCompleted)

    @listenTo Actions.longPollConnected, =>
      @_processQueue()

  queue: =>
    @_queue

  ###
  Public: Returns an existing task in the queue that matches the type you provide,
  and any other match properties. Useful for checking to see if something, like
  a "SendDraft" task is in-flight.

  - `type`: The string name of the task class, or the Task class itself. (ie:
    {SaveDraftTask} or 'SaveDraftTask')

  - `matching`: Optional An {Object} with criteria to pass to _.isMatch. For a
     SaveDraftTask, this could be {draftLocalId: "123123"}

  Returns a matching {Task}, or null.
  ###
  findTask: (type, matching = {}) ->
    type = type.name unless _.isString(type)
    match = _.find @_queue, (task) -> task.constructor.name is type and _.isMatch(task, matching)
    match ? null

  enqueue: (task) =>
    if not (task instanceof Task)
      throw new Error("You must queue a `Task` instance")
    if not task.id
      throw new Error("Tasks must have an ID prior to being queued. Check that your Task constructor is calling `super`")
    if not task.queueState
      throw new Error("Tasks must have a queueState prior to being queued. Check that your Task constructor is calling `super`")

    @_dequeueObsoleteTasks(task)
    task.runLocal().then =>
      @_queue.push(task)

      # We want to make sure the task has made it onto the queue before
      # `performLocalComplete` runs. Code in the `performLocalComplete`
      # callback might depend on knowing that the Task is present in the
      # queue. For example, when we're sending a message I want to know if
      # there's already a task on the queue so I don't double-send.
      task.performLocalComplete()
      @_updateSoon()

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
    for task in @_queue by -1
      continue if @_taskIsBlocked(task)
      @_processTask(task)

  _processTask: (task) =>
    return if task.queueState.isProcessing

    task.queueState.isProcessing = true
    task.runRemote()
    .finally =>
      task.queueState.isProcessing = false
      @trigger()
    .then (status) =>
      @dequeue(task) unless status is Task.Status.Retry
    .catch (err) =>
      console.warn("Task #{task.constructor.name} threw an error: #{err}.")
      @dequeue(task)

  _dequeueObsoleteTasks: (task) =>
    obsolete = _.filter @_queue, (otherTask) =>
      # Do not interrupt tasks which are currently processing
      return false if otherTask.queueState.isProcessing
      # Do not remove ourselves from the queue
      return false if otherTask is task
      # Dequeue tasks which our new task indicates it makes obsolete
      return task.shouldDequeueOtherTask(otherTask)

    for otherTask in obsolete
      @dequeue(otherTask)


  _taskIsBlocked: (task) =>
    _.any @_queue, (otherTask) ->
      task.shouldWaitForTask(otherTask) and task isnt otherTask

  _resolveTaskArgument: (taskOrId) =>
    if not taskOrId
      return null
    else if taskOrId instanceof Task
      return _.find @_queue, (task) -> task is taskOrId
    else
      return _.findWhere(@_queue, id: taskOrId)

  _restoreQueueFromDisk: =>
    {modelReviver} = require '../models/utils'
    try
      queueFile = path.join(atom.getConfigDirPath(), 'task-queue.json')
      queue = JSON.parse(fs.readFileSync(queueFile), modelReviver)
      # We need to set the processing bit back to false so it gets
      # re-retried upon inflation
      for task in queue
        task.queueState ?= {}
        task.queueState.isProcessing = false
      @_queue = queue
    catch e
      if not atom.inSpecMode()
        console.log("Queue deserialization failed with error: #{e.toString()}")

  _saveQueueToDisk: =>
    # It's very important that we debounce saving here. When the user bulk-archives
    # items, they can easily process 1000 tasks at the same moment. We can't try to
    # save 1000 times! (Do not remove debounce without a plan!)
    @_saveDebounced ?= _.debounce =>
      queueFile = path.join(atom.getConfigDirPath(), 'task-queue.json')
      queueJSON = JSON.stringify((@_queue ? []))
      fs.writeFile(queueFile, queueJSON)
    , 150
    @_saveDebounced()

  _updateSoon: =>
    @_updateSoonThrottled ?= _.throttle =>
      @_processQueue()
      @_saveQueueToDisk()
      @trigger()
    , 10, {leading: false}
    @_updateSoonThrottled()

module.exports = new TaskQueue()
