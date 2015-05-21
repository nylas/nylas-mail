Actions = require '../../src/flux/actions'
TaskQueue = require '../../src/flux/stores/task-queue'
Task = require '../../src/flux/tasks/task'

{isTempId} = require '../../src/flux/models/utils'

{APIError,
 OfflineError,
 TimeoutError} = require '../../src/flux/errors'

class TaskSubclassA extends Task
  constructor: (val) -> @aProp = val # forgot to call super

class TaskSubclassB extends Task
  constructor: (val) -> @bProp = val; super

describe "TaskQueue", ->

  makeUnstartedTask = (task) ->
    TaskQueue._initializeTask(task)
    return task

  makeLocalStarted = (task) ->
    TaskQueue._initializeTask(task)
    task.queueState.isProcessing = true
    return task

  makeLocalFailed = (task) ->
    TaskQueue._initializeTask(task)
    task.queueState.performedLocal = Date.now()
    return task

  makeRemoteStarted = (task) ->
    TaskQueue._initializeTask(task)
    task.queueState.isProcessing = true
    task.queueState.remoteAttempts = 1
    task.queueState.performedLocal = Date.now()
    return task

  makeRemoteSuccess = (task) ->
    TaskQueue._initializeTask(task)
    task.queueState.remoteAttempts = 1
    task.queueState.performedLocal = Date.now()
    task.queueState.performedRemote = Date.now()
    return task

  makeRemoteFailed = (task) ->
    TaskQueue._initializeTask(task)
    task.queueState.remoteAttempts = 1
    task.queueState.performedLocal = Date.now()
    return task

  beforeEach ->
    @task              = new Task()
    @unstartedTask     = makeUnstartedTask(new Task())
    @localStarted      = makeLocalStarted(new Task())
    @localFailed       = makeLocalFailed(new Task())
    @remoteStarted     = makeRemoteStarted(new Task())
    @remoteSuccess     = makeRemoteSuccess(new Task())
    @remoteFailed      = makeRemoteFailed(new Task())

  unstartedTask = (task) ->
    taks.queueState.shouldRetry = false
    taks.queueState.isProcessing = false
    taks.queueState.remoteAttempts = 0
    taks.queueState.perfomredLocal = false
    taks.queueState.performedRemote = false
    taks.queueState.notifiedOffline = false

  startedTask = (task) ->
    taks.queueState.shouldRetry = false
    taks.queueState.isProcessing = true
    taks.queueState.remoteAttempts = 0
    taks.queueState.perfomredLocal = false
    taks.queueState.performedRemote = false
    taks.queueState.notifiedOffline = false

  localTask = (task) ->
    taks.queueState.shouldRetry = false
    taks.queueState.isProcessing = true
    taks.queueState.remoteAttempts = 0
    taks.queueState.perfomredLocal = false
    taks.queueState.performedRemote = false
    taks.queueState.notifiedOffline = false

  localSpy = (task) ->
    spyOn(task, "performLocal").andCallFake -> Promise.resolve()

  remoteSpy = (task) ->
    spyOn(task, "performRemote").andCallFake -> Promise.resolve()

  describe "findTask", ->
    beforeEach ->
      @subclassA = new TaskSubclassA()
      @subclassB1 = new TaskSubclassB("B1")
      @subclassB2 = new TaskSubclassB("B2")
      TaskQueue._queue = [@subclassA, @subclassB1, @subclassB2]

    it "accepts type as a string", ->
      expect(TaskQueue.findTask('TaskSubclassB', {bProp: 'B1'})).toEqual(@subclassB1)

    it "accepts type as a class", ->
      expect(TaskQueue.findTask(TaskSubclassB, {bProp: 'B1'})).toEqual(@subclassB1)

    it "works without a set of match criteria", ->
      expect(TaskQueue.findTask(TaskSubclassA)).toEqual(@subclassA)

    it "only returns a task that matches the criteria", ->
      expect(TaskQueue.findTask(TaskSubclassB, {bProp: 'B1'})).toEqual(@subclassB1)
      expect(TaskQueue.findTask(TaskSubclassB, {bProp: 'B2'})).toEqual(@subclassB2)
      expect(TaskQueue.findTask(TaskSubclassB, {bProp: 'B3'})).toEqual(null)

  describe "enqueue", ->
    it "makes sure you've queued a real task", ->
      expect( -> TaskQueue.enqueue("asamw")).toThrow()

    it "adds it to the queue", ->
      TaskQueue.enqueue(@task)
      expect(TaskQueue._queue.length).toBe 1

    it "notifies the queue should be processed", ->
      spyOn(TaskQueue, "_processTask")
      spyOn(TaskQueue, "_processQueue").andCallThrough()

      TaskQueue.enqueue(@task)

      expect(TaskQueue._processQueue).toHaveBeenCalled()
      expect(TaskQueue._processTask).toHaveBeenCalledWith(@task)
      expect(TaskQueue._processTask.calls.length).toBe 1

    it "ensures all tasks have an id", ->
      TaskQueue.enqueue(new TaskSubclassA())
      TaskQueue.enqueue(new TaskSubclassB())
      expect(isTempId(TaskQueue._queue[0].id)).toBe true
      expect(isTempId(TaskQueue._queue[1].id)).toBe true

    it "dequeues Obsolete tasks", ->
      class KillsTaskA extends Task
        constructor: ->
        shouldDequeueOtherTask: (other) -> other instanceof TaskSubclassA

      taskToDie = makeRemoteFailed(new TaskSubclassA())

      spyOn(TaskQueue, "dequeue").andCallThrough()

      TaskQueue._queue = [taskToDie, @remoteFailed]
      TaskQueue.enqueue(new KillsTaskA())

      expect(TaskQueue._queue.length).toBe 2
      expect(TaskQueue.dequeue).toHaveBeenCalledWith(taskToDie, silent: true)
      expect(TaskQueue.dequeue.calls.length).toBe 1

  describe "dequeue", ->
    beforeEach ->
      TaskQueue._queue = [@unstartedTask,
                          @localStarted,
                          @remoteStarted,
                          @remoteFailed]

    it "grabs the task by object", ->
      found = TaskQueue._parseArgs(@remoteStarted)
      expect(found).toBe @remoteStarted

    it "grabs the task by id", ->
      found = TaskQueue._parseArgs(@remoteStarted.id)
      expect(found).toBe @remoteStarted

    it "throws an error if the task isn't found", ->
      expect( -> TaskQueue.dequeue("bad")).toThrow()

    it "calls cleanup on dequeued tasks", ->
      spyOn(@remoteStarted, "cleanup")
      TaskQueue.dequeue(@remoteStarted, silent: true)
      expect(@remoteStarted.cleanup).toHaveBeenCalled()

    it "moves it from the queue", ->
      TaskQueue.dequeue(@remoteStarted, silent: true)
      expect(TaskQueue._queue.length).toBe 3
      expect(TaskQueue._completed.length).toBe 1

    it "marks it as no longer processing", ->
      TaskQueue.dequeue(@remoteStarted, silent: true)
      expect(@remoteStarted.queueState.isProcessing).toBe false

    it "notifies the queue has been updated", ->
      spyOn(TaskQueue, "_processQueue")

      TaskQueue.dequeue(@remoteStarted)

      expect(TaskQueue._processQueue).toHaveBeenCalled()
      expect(TaskQueue._processQueue.calls.length).toBe 1

  describe "process Task", ->
    it "doesn't process processing tasks", ->
      localSpy(@remoteStarted)
      remoteSpy(@remoteStarted)
      TaskQueue._processTask(@remoteStarted)
      expect(@remoteStarted.performLocal).not.toHaveBeenCalled()
      expect(@remoteStarted.performRemote).not.toHaveBeenCalled()

    it "doesn't process blocked tasks", ->
      class BlockedByTaskA extends Task
        constructor: ->
        shouldWaitForTask: (other) -> other instanceof TaskSubclassA

      blockedByTask = new BlockedByTaskA()
      localSpy(blockedByTask)
      remoteSpy(blockedByTask)

      blockingTask = makeRemoteFailed(new TaskSubclassA())

      TaskQueue._queue = [blockingTask, @remoteFailed]
      TaskQueue.enqueue(blockedByTask)

      expect(TaskQueue._queue.length).toBe 3
      expect(blockedByTask.performLocal).not.toHaveBeenCalled()
      expect(blockedByTask.performRemote).not.toHaveBeenCalled()

    it "doesn't block itself", ->
      class BlockingTask extends Task
        constructor: ->
        shouldWaitForTask: (other) -> other instanceof BlockingTask

      blockedByTask = new BlockingTask()
      localSpy(blockedByTask)
      remoteSpy(blockedByTask)

      blockingTask = makeRemoteFailed(new BlockingTask())

      TaskQueue._queue = [blockingTask, @remoteFailed]
      TaskQueue.enqueue(blockedByTask)

      expect(TaskQueue._queue.length).toBe 3
      expect(blockedByTask.performLocal).not.toHaveBeenCalled()
      expect(blockedByTask.performRemote).not.toHaveBeenCalled()

    it "sets the processing bit", ->
      localSpy(@unstartedTask)
      TaskQueue._queue = [@unstartedTask]
      TaskQueue._processTask(@unstartedTask)
      expect(@unstartedTask.queueState.isProcessing).toBe true

    it "performs local if it's a fresh task", ->
      localSpy(@unstartedTask)
      TaskQueue._queue = [@unstartedTask]
      TaskQueue._processTask(@unstartedTask)
      expect(@unstartedTask.performLocal).toHaveBeenCalled()

  describe "performLocal", ->
    it "on success it marks it as complete with the timestamp", ->
      localSpy(@unstartedTask)
      remoteSpy(@unstartedTask)
      runs ->
        TaskQueue.enqueue(@unstartedTask)
      waitsFor =>
        @unstartedTask.queueState.performedLocal isnt false
      runs ->
        expect(@unstartedTask.queueState.performedLocal).toBeGreaterThan 0

    it "throws an error if it fails", ->
      spyOn(@unstartedTask, "performLocal").andCallFake -> Promise.reject("boo")
      remoteSpy(@unstartedTask)
      runs ->
        TaskQueue.enqueue(@unstartedTask)
      waitsFor =>
        @unstartedTask.queueState.isProcessing == false
      runs ->
        expect(@unstartedTask.queueState.localError).toBe "boo"
        expect(@unstartedTask.performLocal).toHaveBeenCalled()
        expect(@unstartedTask.performRemote).not.toHaveBeenCalled()

    it "dequeues the task if it fails locally", ->
      spyOn(@unstartedTask, "performLocal").andCallFake -> Promise.reject("boo")
      remoteSpy(@unstartedTask)
      runs ->
        TaskQueue.enqueue(@unstartedTask)
      waitsFor =>
        @unstartedTask.queueState.isProcessing == false
      runs ->
        expect(TaskQueue._queue.length).toBe 0
        expect(TaskQueue._completed.length).toBe 1

  describe "performRemote", ->
    beforeEach ->
      localSpy(@unstartedTask)

    it "performs remote properly", ->
      remoteSpy(@unstartedTask)
      runs ->
        TaskQueue.enqueue(@unstartedTask)
      waitsFor =>
        @unstartedTask.queueState.performedRemote isnt false
      runs ->
        expect(@unstartedTask.performLocal).toHaveBeenCalled()
        expect(@unstartedTask.performRemote).toHaveBeenCalled()

    it "dequeues on success", ->
      remoteSpy(@unstartedTask)
      runs ->
        TaskQueue.enqueue(@unstartedTask)
      waitsFor =>
        @unstartedTask.queueState.isProcessing is false and
        @unstartedTask.queueState.performedRemote > 0
      runs ->
        expect(TaskQueue._queue.length).toBe 0
        expect(TaskQueue._completed.length).toBe 1

    it "notifies we're offline the first time", ->
      spyOn(TaskQueue, "_isOnline").andReturn false
      remoteSpy(@unstartedTask)
      spyOn(@unstartedTask, "onError")
      runs ->
        TaskQueue.enqueue(@unstartedTask)
      waitsFor =>
        @unstartedTask.queueState.notifiedOffline == true
      runs ->
        expect(@unstartedTask.performLocal).toHaveBeenCalled()
        expect(@unstartedTask.performRemote).not.toHaveBeenCalled()
        expect(@unstartedTask.onError).toHaveBeenCalled()
        expect(@unstartedTask.queueState.isProcessing).toBe false
        expect(@unstartedTask.onError.calls[0].args[0] instanceof OfflineError).toBe true

    it "doesn't notify we're offline the second+ time", ->
      spyOn(TaskQueue, "_isOnline").andReturn false
      localSpy(@remoteFailed)
      remoteSpy(@remoteFailed)
      spyOn(@remoteFailed, "onError")
      @remoteFailed.queueState.notifiedOffline = true
      TaskQueue._queue = [@remoteFailed]
      runs ->
        TaskQueue._processQueue()
      waitsFor =>
        @remoteFailed.queueState.isProcessing is false
      runs ->
        expect(@remoteFailed.performLocal).not.toHaveBeenCalled()
        expect(@remoteFailed.performRemote).not.toHaveBeenCalled()
        expect(@remoteFailed.onError).not.toHaveBeenCalled()

    it "marks performedRemote on success", ->
      remoteSpy(@unstartedTask)
      runs ->
        TaskQueue.enqueue(@unstartedTask)
      waitsFor =>
        @unstartedTask.queueState.performedRemote isnt false
      runs ->
        expect(@unstartedTask.queueState.performedRemote).toBeGreaterThan 0

    it "on failure it notifies of the error", ->
      err = new APIError
      spyOn(@unstartedTask, "performRemote").andCallFake -> Promise.reject(err)
      spyOn(@unstartedTask, "onError")
      runs ->
        TaskQueue.enqueue(@unstartedTask)
      waitsFor =>
        @unstartedTask.queueState.isProcessing is false
      runs ->
        expect(@unstartedTask.performLocal).toHaveBeenCalled()
        expect(@unstartedTask.performRemote).toHaveBeenCalled()
        expect(@unstartedTask.onError).toHaveBeenCalledWith(err)

    it "dequeues on failure", ->
      err = new APIError
      spyOn(@unstartedTask, "performRemote").andCallFake -> Promise.reject(err)
      runs ->
        TaskQueue.enqueue(@unstartedTask)
      waitsFor =>
        @unstartedTask.queueState.isProcessing is false
      runs ->
        expect(TaskQueue._queue.length).toBe 0
        expect(TaskQueue._completed.length).toBe 1

    it "on failure it sets the appropriate bits", ->
      err = new APIError
      spyOn(@unstartedTask, "performRemote").andCallFake -> Promise.reject(err)
      spyOn(@unstartedTask, "onError")
      runs ->
        TaskQueue.enqueue(@unstartedTask)
      waitsFor =>
        @unstartedTask.queueState.isProcessing is false
      runs ->
        expect(@unstartedTask.queueState.notifiedOffline).toBe false
        expect(@unstartedTask.queueState.remoteError).toBe err

  describe "under stress", ->
    beforeEach ->
      TaskQueue._queue = [@unstartedTask,
                          @remoteFailed]
    it "when all tasks pass it processes all items", ->
      for task in TaskQueue._queue
        localSpy(task)
        remoteSpy(task)
      runs ->
        TaskQueue.enqueue(new Task)
      waitsFor ->
        TaskQueue._queue.length is 0
      runs ->
        expect(TaskQueue._completed.length).toBe 3
