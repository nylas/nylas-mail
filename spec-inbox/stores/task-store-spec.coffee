Actions = require '../../src/flux/actions'
TaskStore = require '../../src/flux/stores/task-store'
Task = require '../../src/flux/tasks/task'

class TaskSubclassA extends Task
  constructor: (val) -> @aProp = val

class TaskSubclassB extends Task
  constructor: (val) -> @bProp = val

describe "TaskStore", ->
  beforeEach ->
    @task = @taskA = new Task
    @taskB = new Task
    @task.shouldWaitForTask = -> false
    @taskWithDependencies = new Task
    @taskWithDependencies.shouldWaitForTask = (other) => (other == @taskA)

  afterEach ->
    TaskStore.reset()

  describe "queueTask", =>
    it "should be called whenever Actions.queueTask is fired", ->
      # TODO: Turns out this is very difficult to test because you can't stub out
      # store methods that are registered as listeners.

    it "should call the task's performLocal function", ->
      spyOn(@task, 'performLocal').andCallFake -> new Promise (resolve, reject) -> @
      TaskStore._onQueueTask(@task)
      expect(@task.performLocal).toHaveBeenCalled()

    it "should immediately put the task on the pending list", ->
      expect(TaskStore.pendingTasks().length).toBe(0)
      TaskStore._onQueueTask(@task)
      expect(TaskStore.pendingTasks().length).toBe(1)
      expect(TaskStore.queuedTasks().length).toBe(0)

    it "should move the task to the queue list when performLocal has finished", ->
      expect(TaskStore.queuedTasks().length).toBe(0)
      runs ->
        spyOn(@task, 'performLocal').andCallFake ->
          new Promise (resolve, reject) ->
            setTimeout(resolve, 1)
        spyOn(TaskStore, 'performNextTask')
        TaskStore._onQueueTask(@task)
        advanceClock(2)
      waitsFor ->
        TaskStore.queuedTasks().length == 1
      runs ->
        expect(TaskStore.queuedTasks().length).toBe(1)
        expect(TaskStore.pendingTasks().length).toBe(0)

  describe "abortTask", =>
    beforeEach ->
      @a1 = new TaskSubclassA('1')
      @a2 = new TaskSubclassA('2')
      @b1 = new TaskSubclassB('bA')
      @b2 = new TaskSubclassB('bB')

      TaskStore._queue = [@a1, @b2]
      TaskStore._pending = [@a2, @b1]

    it "should remove tasks whose JSON match the criteria", ->
      TaskStore._onAbortTask({object: 'TaskSubclassA'})
      expect(TaskStore._queue).toEqual([@b2])
      expect(TaskStore._pending).toEqual([@b1])

      TaskStore._onAbortTask({bProp: 'bB'})
      expect(TaskStore._queue).toEqual([])
      expect(TaskStore._pending).toEqual([@b1])

    it "should call cleanup on each removed task", ->
      spyOn(@a1, 'cleanup')
      TaskStore._onAbortTask({object: 'TaskSubclassA'})
      expect(@a1.cleanup).toHaveBeenCalled()

    it "should call rollbackLocal on each removed task iff the rollbackLocal flag is passed", ->
      spyOn(@a1, 'rollbackLocal')
      TaskStore._onAbortTask({aProp: '1'})
      expect(@a1.rollbackLocal).toHaveBeenCalled()

      spyOn(@a2, 'rollbackLocal')
      TaskStore._onAbortTask({aProp: '2'}, {rollbackLocal: false})
      expect(@a2.rollbackLocal).not.toHaveBeenCalled()

    it "should call abort on each pending removed task", ->
      spyOn(@a1, 'abort')
      spyOn(@a2, 'abort')
      TaskStore._onAbortTask({object: 'TaskSubclassA'})
      expect(@a2.abort).toHaveBeenCalled()
      expect(@a1.abort).not.toHaveBeenCalled()


  describe "canPerformTask", =>
    beforeEach ->
      TaskStore._queue = [@taskWithDependencies, @taskA]
      TaskStore._pending = []

    it "should return true if the task provided has no dependencies in the queue", ->
      expect(TaskStore.canPerformTask(@taskA)).toBe(true)

    it "should return false if the task returns dependencies", ->
      expect(TaskStore.canPerformTask(@taskWithDependencies)).toBe(false)


  describe "performNextTask", =>
    beforeEach ->
      TaskStore._queue = [@taskWithDependencies, @taskA, @taskB]
      TaskStore._pending = []

    it "should remove the first ready task from the queue", ->
      expect(TaskStore.canPerformTask(@taskWithDependencies)).toBe(false)
      expect(TaskStore.queuedTasks().length).toBe(3)
      TaskStore.performNextTask()
      expect(TaskStore.queuedTasks().length).toBe(2)
      expect(TaskStore.queuedTasks()).toEqual([@taskWithDependencies, @taskB])

    it "should add the task to the pending list", ->
      TaskStore.performNextTask()
      expect(TaskStore.pendingTasks()).toEqual([@taskA])

    it "should call the task's performRemote function", ->
      spyOn(@taskA, 'performRemote').andReturn(Promise.resolve())
      TaskStore.performNextTask()
      expect(@taskA.performRemote).toHaveBeenCalled()

    describe "when performRemote finishes", ->
      beforeEach ->
        spyOn(@taskA, 'performRemote').andReturn(Promise.resolve())

      it "should clean up the task", ->
        spyOn(@taskA, 'cleanup')
        waitsForPromise -> TaskStore.performNextTask()
        runs ->
          expect(@taskA.cleanup).toHaveBeenCalled()

      it "should remove the task from the pending list", ->
        waitsForPromise -> TaskStore.performNextTask()
        runs ->
          expect(TaskStore.pendingTasks()).toEqual([])

      it "should update the disk cache and perform the next task", ->
        spyOn(TaskStore, 'performNextTask').andCallThrough()
        spyOn(TaskStore, 'persist').andCallFake (callback) ->
          callback() if callback

        waitsForPromise -> TaskStore.performNextTask()
        runs ->
          expect(TaskStore.persist).toHaveBeenCalled()
          expect(TaskStore.performNextTask.callCount).toBe(3)

    describe "when performRemote finishes with a failure", ->
      beforeEach ->
        spyOn(TaskStore, '_displayError')
        spyOn(@taskA, 'performRemote').andReturn(Promise.reject('An error!'))

      describe "when shouldRetry returns true", ->
        beforeEach ->
          spyOn(@taskA, 'shouldRetry').andReturn(true)

        it "should put the task back on the queue", ->
          waitsForPromise -> TaskStore.performNextTask()
          runs ->
            expect(TaskStore.queuedTasks()).toEqual([@taskWithDependencies, @taskB, @taskA])

      describe "when shouldRetry returns false", ->
        beforeEach ->
          spyOn(@taskA, 'shouldRetry').andReturn(false)

        it "should roll back the performLocal function and throw out the task", ->
          spyOn(@taskA, 'rollbackLocal')
          waitsForPromise -> TaskStore.performNextTask()
          runs ->
            expect(@taskA.rollbackLocal).toHaveBeenCalled()

