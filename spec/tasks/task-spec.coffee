Actions = require '../../src/flux/actions'
TaskQueue = require '../../src/flux/stores/task-queue'
Task = require '../../src/flux/tasks/task'

{APIError,
 TimeoutError} = require '../../src/flux/errors'

noop = ->

describe "Task", ->
  describe "initial state", ->
    it "should set up queue state with additional information about local/remote", ->
      task = new Task()
      expect(task.queueState).toEqual({ isProcessing : false, localError : null, localComplete : false, remoteError : null, remoteAttempts : 0, remoteComplete : false, status: null, debugStatus: Task.DebugStatus.JustConstructed})

  describe "runLocal", ->
    beforeEach ->
      class APITestTask extends Task
        performLocal: -> Promise.resolve()
        performRemote: -> Promise.resolve(Task.Status.Success)
      @task = new APITestTask()

    describe "when performLocal is not complete", ->
      it "should run performLocal", ->
        spyOn(@task, 'performLocal').andCallThrough()
        @task.runLocal()
        expect(@task.performLocal).toHaveBeenCalled()

      describe "when performLocal rejects", ->
        beforeEach ->
          spyOn(NylasEnv, "reportError")
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

      it "it should resolve Continue if it already ran", ->
        @task.queueState.remoteComplete = true
        waitsForPromise =>
          @task.runRemote().then (status) =>
            expect(@task.queueState.status).toBe Task.Status.Continue
            expect(status).toBe Task.Status.Continue

      it "marks as complete if the task 'continue's", ->
        spyOn(@task, 'performRemote').andCallFake ->
          Promise.resolve(Task.Status.Continue)
          @task.runRemote()
          advanceClock()
          expect(@task.performRemote).toHaveBeenCalled()
          expect(@task.queueState.remoteError).toBe(null)
          expect(@task.queueState.remoteComplete).toBe(true)
          expect(@task.queueState.status).toBe(Task.Status.Continue)

      it "marks as failed if the task reverts", ->
        spyOn(@task, 'performRemote').andCallFake ->
          Promise.resolve(Task.Status.Failed)
          @task.runRemote()
          advanceClock()
          expect(@task.performRemote).toHaveBeenCalled()
          expect(@task.queueState.remoteError).toBe(null)
          expect(@task.queueState.remoteComplete).toBe(true)
          expect(@task.queueState.status).toBe(Task.Status.Failed)

      describe "when performRemote resolves", ->
        beforeEach ->
          spyOn(@task, 'performRemote').andCallFake ->
            Promise.resolve(Task.Status.Success)

        it "should save that performRemote is complete with no errors", ->
          @task.runRemote()
          advanceClock()
          expect(@task.performRemote).toHaveBeenCalled()
          expect(@task.queueState.remoteError).toBe(null)
          expect(@task.queueState.remoteComplete).toBe(true)
          expect(@task.queueState.status).toBe(Task.Status.Success)

        it "should only allow the performRemote method to return a Task.Status", ->
          result = null
          err = null

          class OKTask extends Task
            performRemote: -> Promise.resolve(Task.Status.Retry)

          @ok = new OKTask()
          @ok.queueState.localComplete = true
          @ok.runRemote().then (r) -> result = r
          advanceClock()
          expect(@ok.queueState.status).toBe(Task.Status.Retry)
          expect(result).toBe(Task.Status.Retry)

          class BadTask extends Task
            performRemote: -> Promise.resolve('lalal')
          @bad = new BadTask()
          @bad.queueState.localComplete = true
          @bad.runRemote().catch (e) -> err = e
          advanceClock()
          expect(err.message).toBe('performRemote returned lalal, which is not a Task.Status')

      describe "when performRemote rejects multiple times", ->
        beforeEach ->
          spyOn(@task, 'performRemote').andCallFake =>
            Promise.resolve(Task.Status.Failed)

        it "should increment the number of attempts", ->
          runs ->
            @task.runRemote().catch(noop)
          waitsFor ->
            @task.queueState.remoteAttempts == 1
          runs ->
            @task.runRemote().catch(noop)
          waitsFor ->
            @task.queueState.remoteAttempts == 2

      describe "when performRemote resolves with Task.Status.Failed", ->
        beforeEach ->
          spyOn(NylasEnv, "reportError")
          @error = new APIError("Oh no!")
          spyOn(@task, 'performRemote').andCallFake =>
            Promise.resolve(Task.Status.Failed)

        it "Should handle the error as a caught Failure", ->
          waitsForPromise =>
            @task.runRemote().then ->
              throw new Error("Should not resolve")
            .catch (err) =>
              expect(@task.queueState.remoteError instanceof Error).toBe true
              expect(@task.queueState.remoteAttempts).toBe(1)
              expect(@task.queueState.status).toBe(Task.Status.Failed)
              expect(NylasEnv.reportError).not.toHaveBeenCalled()

      describe "when performRemote resolves with Task.Status.Failed and an error", ->
        beforeEach ->
          spyOn(NylasEnv, "reportError")
          @error = new APIError("Oh no!")
          spyOn(@task, 'performRemote').andCallFake =>
            Promise.resolve([Task.Status.Failed, @error])

        it "Should handle the error as a caught Failure", ->
          waitsForPromise =>
            @task.runRemote().then ->
              throw new Error("Should not resolve")
            .catch (err) =>
              expect(@task.queueState.remoteError).toBe(@error)
              expect(@task.queueState.remoteAttempts).toBe(1)
              expect(@task.queueState.status).toBe(Task.Status.Failed)
              expect(NylasEnv.reportError).not.toHaveBeenCalled()

      describe "when performRemote rejects with Task.Status.Failed", ->
        beforeEach ->
          spyOn(NylasEnv, "reportError")
          @error = new APIError("Oh no!")
          spyOn(@task, 'performRemote').andCallFake =>
            Promise.reject([Task.Status.Failed, @error])

        it "Should handle the rejection as normal", ->
          waitsForPromise =>
            @task.runRemote().then ->
              throw new Error("Should not resolve")
            .catch (err) =>
              expect(@task.queueState.remoteError).toBe(@error)
              expect(@task.queueState.remoteAttempts).toBe(1)
              expect(@task.queueState.status).toBe(Task.Status.Failed)
              expect(NylasEnv.reportError).not.toHaveBeenCalled()

      describe "when performRemote throws an unknown error", ->
        beforeEach ->
          spyOn(NylasEnv, "reportError")
          @error = new Error("Oh no!")
          spyOn(@task, 'performRemote').andCallFake =>
            throw @error

        it "Should handle the error as an uncaught error", ->
          waitsForPromise =>
            @task.runRemote().then ->
              throw new Error("Should not resolve")
            .catch (err) =>
              expect(@task.queueState.remoteError).toBe(@error)
              expect(@task.queueState.remoteAttempts).toBe(1)
              expect(@task.queueState.status).toBe(Task.Status.Failed)
              expect(@task.queueState.debugStatus).toBe(Task.DebugStatus.UncaughtError)
              expect(NylasEnv.reportError).toHaveBeenCalledWith(@error)
