Actions = require '../../src/flux/actions'
TaskQueue = require '../../src/flux/stores/task-queue'
Task = require '../../src/flux/tasks/task'

{APIError,
 OfflineError,
 TimeoutError} = require '../../src/flux/errors'

noop = ->

describe "Task", ->
  describe "initial state", ->
    it "should set up queue state with additional information about local/remote", ->
      task = new Task()
      expect(task.queueState).toEqual({ isProcessing : false, localError : null, localComplete : false, remoteError : null, remoteAttempts : 0, remoteComplete : false })

  describe "runLocal", ->
    beforeEach ->
      class APITestTask extends Task
        performLocal: -> Promise.resolve()
        performRemote: -> Promise.resolve(Task.Status.Finished)
      @task = new APITestTask()

    describe "when performLocal is not complete", ->
      it "should run performLocal", ->
        spyOn(@task, 'performLocal').andCallThrough()
        @task.runLocal()
        expect(@task.performLocal).toHaveBeenCalled()

      describe "when performLocal rejects", ->
        beforeEach ->
          spyOn(@task, 'performLocal').andCallFake =>
            Promise.reject(new Error("Oh no!"))

        it "should save the error to the queueState", ->
          @task.runLocal().catch(noop)
          advanceClock()
          expect(@task.performLocal).toHaveBeenCalled()
          expect(@task.queueState.localComplete).toBe(false)
          expect(@task.queueState.localError.message).toBe("Oh no!")

        it "should reject with the error", ->
          rejection = null
          runs ->
            @task.runLocal().catch (err) ->
              rejection = err
          waitsFor ->
            rejection
          runs ->
            expect(rejection.message).toBe("Oh no!")

      describe "when performLocal resolves", ->
        beforeEach ->
          spyOn(@task, 'performLocal').andCallFake -> Promise.resolve('Hooray')

        it "should save that performLocal is complete", ->
          @task.runLocal()
          advanceClock()
          expect(@task.queueState.localComplete).toBe(true)

        it "should save that there was no performLocal error", ->
          @task.runLocal()
          advanceClock()
          expect(@task.queueState.localError).toBe(null)

    describe "runRemote", ->
      beforeEach ->
        @task.queueState.localComplete = true

      it "should run performRemote", ->
        spyOn(@task, 'performRemote').andCallThrough()
        @task.runRemote()
        advanceClock()
        expect(@task.performRemote).toHaveBeenCalled()

      describe "when performRemote resolves", ->
        beforeEach ->
          spyOn(@task, 'performRemote').andCallFake ->
            Promise.resolve(Task.Status.Finished)

        it "should save that performRemote is complete with no errors", ->
          @task.runRemote()
          advanceClock()
          expect(@task.performRemote).toHaveBeenCalled()
          expect(@task.queueState.remoteError).toBe(null)
          expect(@task.queueState.remoteComplete).toBe(true)

        it "should only allow the performRemote method to return a Task.Status", ->
          result = null
          err = null

          class OKTask extends Task
            performRemote: -> Promise.resolve(Task.Status.Retry)

          @ok = new OKTask()
          @ok.queueState.localComplete = true
          @ok.runRemote().then (r) -> result = r
          advanceClock()
          expect(result).toBe(Task.Status.Retry)

          class BadTask extends Task
            performRemote: -> Promise.resolve('lalal')
          @bad = new BadTask()
          @bad.queueState.localComplete = true
          @bad.runRemote().catch (e) -> err = e
          advanceClock()
          expect(err.message).toBe('performRemote returned lalal, which is not a Task.Status')

      describe "when performRemote rejects", ->
        beforeEach ->
          @error = new APIError("Oh no!")
          spyOn(@task, 'performRemote').andCallFake => Promise.reject(@error)

        it "should save the error to the queueState", ->
          @task.runRemote().catch(noop)
          advanceClock()
          expect(@task.queueState.remoteError).toBe(@error)

        it "should increment the number of attempts", ->
          runs ->
            @task.runRemote().catch(noop)
          waitsFor ->
            @task.queueState.remoteAttempts == 1
          runs ->
            @task.runRemote().catch(noop)
          waitsFor ->
            @task.queueState.remoteAttempts == 2
