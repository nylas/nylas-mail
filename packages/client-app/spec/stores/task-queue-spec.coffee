Actions = require('../../src/flux/actions').default
DatabaseStore = require('../../src/flux/stores/database-store').default
TaskQueue = require '../../src/flux/stores/task-queue'
Task = require('../../src/flux/tasks/task').default
DatabaseObjectRegistry = require('../../src/registries/database-object-registry').default

{APIError} = require '../../src/flux/errors'

{TaskSubclassA,
 TaskSubclassB,
 KillsTaskA,
 BlockedByTaskA,
 BlockingTask,
 TaskAA,
 TaskBB} = require('./task-subclass')

xdescribe "TaskQueue", ->

  makeUnstartedTask = (task) ->
    task

  makeProcessing = (task) ->
    task.queueState.isProcessing = true
    task

  makeRetryInFuture = (task) ->
    task.queueState.retryAfter = Date.now() + 1000
    task.queueState.retryDelay = 1000
    task

  beforeEach ->
    spyOn(DatabaseObjectRegistry, 'isInRegistry').andReturn(true)
    @task              = new Task()
    @unstartedTask     = makeUnstartedTask(new Task())
    @processingTask    = makeProcessing(new Task())
    @retryInFutureTask = makeRetryInFuture(new Task())

  afterEach ->
    # Flush any throttled or debounced updates
    advanceClock(1000)

  describe "restoreQueue", ->
    it "should fetch the queue from the database, reset flags and start processing", ->
      queue = [@processingTask, @unstartedTask, @retryInFutureTask]
      spyOn(DatabaseStore, 'findJSONBlob').andCallFake => Promise.resolve(queue)
      spyOn(TaskQueue, '_updateSoon')

      waitsForPromise =>
        TaskQueue._restoreQueue().then =>
          expect(TaskQueue._queue).toEqual(queue)
          expect(@processingTask.queueState.isProcessing).toEqual(false)
          expect(@retryInFutureTask.queueState.retryAfter).toEqual(undefined)
          expect(@retryInFutureTask.queueState.retryDelay).toEqual(undefined)
          expect(TaskQueue._updateSoon).toHaveBeenCalled()

    it "should remove any items in the queue which were not deserialized as tasks", ->
      queue = [@processingTask, {type: 'bla'}, @retryInFutureTask]
      spyOn(DatabaseStore, 'findJSONBlob').andCallFake => Promise.resolve(queue)
      spyOn(TaskQueue, '_updateSoon')
      waitsForPromise =>
        TaskQueue._restoreQueue().then =>
          expect(TaskQueue._queue).toEqual([@processingTask, @retryInFutureTask])

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
      expect(TaskQueue.findTask(TaskSubclassB, {bProp: 'B3'})).toEqual(undefined)

