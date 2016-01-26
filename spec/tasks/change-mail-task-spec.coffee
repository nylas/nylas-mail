_ = require 'underscore'

{APIError,
 Folder,
 Thread,
 Message,
 ACtions,
 NylasAPI,
 Query,
 DatabaseStore,
 DatabaseTransaction,
 Task,
 Utils,
 ChangeMailTask} = require 'nylas-exports'

describe "ChangeMailTask", ->
  beforeEach ->
    @threadA = new Thread(id: 'A', folders: [new Folder(id:'folderA')])
    @threadB = new Thread(id: 'B', folders: [new Folder(id:'folderB')])
    @threadC = new Thread(id: 'C', folders: [new Folder(id:'folderC')])
    @threadAChanged = new Thread(id: 'A', folders: [new Folder(id:'folderC')])

    @threadAMesage1 = new Message(id:'A1', threadId: 'A')
    @threadAMesage2 = new Message(id:'A2', threadId: 'A')
    @threadBMesage1 = new Message(id:'B1', threadId: 'B')

    threads = [@threadA, @threadB, @threadC]
    messages = [@threadAMesage1, @threadAMesage2, @threadBMesage1]

    # Instead of spying on find/findAll, we fake the evaluation of the query.
    # This allows queries to be built with findAll().where().blabla... without
    # a complex stub chain. Works since query "matchers" can be evaluated in JS
    spyOn(DatabaseStore, 'run').andCallFake (query) =>
      if query._klass is Message
        models = messages
      else if query._klass is Thread
        models = threads
      else
        throw new Error("Not stubbed!")

      models = models.filter (model) ->
        for matcher in query._matchers
          if matcher.evaluate(model) is false
            return false
        return true

      if query._singular
        models = models[0]
      Promise.resolve(models)

    spyOn(DatabaseTransaction.prototype, 'persistModels').andReturn(Promise.resolve())
    spyOn(DatabaseTransaction.prototype, 'persistModel').andReturn(Promise.resolve())

  it "leaves subclasses to implement changesToModel", ->
    task = new ChangeMailTask()
    expect( => task.changesToModel() ).toThrow()

  it "leaves subclasses to implement requestBodyForModel", ->
    task = new ChangeMailTask()
    expect( => task.requestBodyForModel() ).toThrow()

  describe "performLocal", ->
    it "rejects if it's an undo task and no restore values are present", ->
      task = new ChangeMailTask()
      task._isUndoTask = true
      spyOn(task, '_performLocalThreads').andReturn(Promise.resolve())

      waitsForPromise =>
        task.performLocal().catch (err) =>
          expect(err.message).toEqual("ChangeMailTask: No _restoreValues provided for undo task.")

    it "should always call _performLocalThreads and then _performLocalMessages", ->
      task = new ChangeMailTask()
      task.threads = [@threadA]

      @messagesResolve = null
      spyOn(task, '_performLocalThreads').andCallFake => Promise.resolve()
      spyOn(task, '_performLocalMessages').andCallFake =>
        new Promise (resolve, reject) => @messagesResolve = resolve

      runs ->
        task.performLocal()
      waitsFor ->
        task._performLocalThreads.callCount > 0
      runs ->
        advanceClock()
        @messagesResolve()
      waitsFor ->
        task._performLocalMessages.callCount > 0
      runs ->
        expect(task._performLocalThreads).toHaveBeenCalled()
        expect(task._performLocalMessages).toHaveBeenCalled()

  describe "_performLocalThreads", ->
    beforeEach ->
      @task = new ChangeMailTask()
      @task.threads = [@threadA, @threadB]
      # Note: Simulate applyChanges only changing threadA, not threadB
      spyOn(@task, '_applyChanges').andReturn([@threadAChanged])

    it "calls _applyChanges and writes changed threads to the database", ->
      waitsForPromise =>
        @task._performLocalThreads().then =>
          expect(@task._applyChanges).toHaveBeenCalledWith(@task.threads)
          expect(DatabaseTransaction.prototype.persistModels).toHaveBeenCalledWith([@threadAChanged])

    describe "when processNestedMessages is overridden to return true", ->
      it "fetches messages on changed threads and appends them to the messages to update", ->
        waitsForPromise =>
          @task.processNestedMessages = => true
          @task._performLocalThreads().then =>
            expect(@task._applyChanges).toHaveBeenCalledWith(@task.threads)
            expect(@task.messages).toEqual([@threadAMesage1, @threadAMesage2])

  describe "_performLocalMessages", ->
    beforeEach ->
      @task = new ChangeMailTask()
      @task.messages = [@threadAMesage1, @threadAMesage2, @threadBMesage1]
      # Note: Simulate applyChanges only changing threadBMesage1
      spyOn(@task, '_applyChanges').andReturn([@threadBMesage1])

    it "calls _applyChanges and writes changed messages to the database", ->
      waitsForPromise =>
        @task._performLocalMessages().then =>
          expect(@task._applyChanges).toHaveBeenCalledWith(@task.messages)
          expect(DatabaseTransaction.prototype.persistModels).toHaveBeenCalledWith([@threadBMesage1])

  describe "_applyChanges", ->
    beforeEach ->
      @task = new ChangeMailTask()

    describe "when applying forwards", ->
      beforeEach ->
        spyOn(@task, '_shouldChangeBackwards').andReturn(false)
        spyOn(@task, 'changesToModel').andCallFake (thread) =>
          if thread is @threadC
            return {folders: [new Folder(id: "different!")]}
          else
            return {folders: thread.folders}

      it "should call changesToModel on each model", ->
        @task._applyChanges([@threadA, @threadB])
        expect(@task.changesToModel.callCount).toBe(2)
        expect(@task.changesToModel.calls[0].args[0]).toBe(@threadA)
        expect(@task.changesToModel.calls[1].args[0]).toBe(@threadB)

      it "should return only the models with new values", ->
        out = @task._applyChanges([@threadA, @threadB, @threadC])
        expect(_.isArray(out)).toBe(true)
        expect(out.length).toBe(1)
        expect(out[0].id).toBe('C')
        expect(out[0].folders[0].id).toBe('different!')

      it "should save restore values only for changed items", ->
        out = @task._applyChanges([@threadA, @threadB, @threadC])
        expect(@task._restoreValues['A']).toBe(undefined)
        expect(@task._restoreValues['B']).toBe(undefined)
        expect(@task._restoreValues['C']).toEqual(folders: @threadC.folders)

      it "should treat models as if they're frozen, returning new models", ->
        out = @task._applyChanges([@threadA, @threadB, @threadC])
        expect(out[0]).not.toBe(@threadC)
        expect(out[0].id).toBe(@threadC.id)
        expect(@task._restoreValues['C']).toEqual(folders: @threadC.folders)

    describe "when applying backwards (reverting or undoing)", ->
      beforeEach ->
        spyOn(@task, '_shouldChangeBackwards').andReturn(true)
        @task._restoreValues =
          'C': {folders: [new Folder(id:'oldFolderC')]}

      it "should return only models with the restore values, with the restore values applied", ->
        out = @task._applyChanges([@threadA, @threadB, @threadC])
        expect(_.isArray(out)).toBe(true)
        expect(out.length).toBe(1)
        expect(out[0].id).toBe('C')
        expect(out[0].folders[0].id).toBe('oldFolderC')

  describe "performRemote", ->
    describe "if threads are set", ->
      it "should only call _performRequests with threads", ->
        @task = new ChangeMailTask()
        @task.threads = [@threadA, @threadB]
        @task.messages = [@threadAMesage1, @threadAMesage2]
        spyOn(@task, '_performRequests').andReturn(Promise.resolve())
        waitsForPromise =>
          @task.performRemote().then =>
            expect(@task._performRequests).toHaveBeenCalledWith(Thread, @task.threads)
            expect(@task._performRequests.callCount).toBe(1)

    describe "if only messages are set", ->
      it "should only call _performRequests with messages", ->
        @task = new ChangeMailTask()
        @task.threads = []
        @task.messages = [@threadAMesage1, @threadAMesage2]
        spyOn(@task, '_performRequests').andReturn(Promise.resolve())
        waitsForPromise =>
          @task.performRemote().then =>
            expect(@task._performRequests).toHaveBeenCalledWith(Message, @task.messages)
            expect(@task._performRequests.callCount).toBe(1)

    describe "if somehow there are no threads or messages", ->
      it "should resolve", ->
        @task = new ChangeMailTask()
        @task.threads = []
        @task.messages = []
        waitsForPromise =>
          @task.performRemote().then (code) =>
            expect(code).toEqual(Task.Status.Success)

    describe "if _performRequests resolves", ->
      it "should resolve with Task.Status.Success", ->
        @task = new ChangeMailTask()
        spyOn(@task, '_performRequests').andReturn(Promise.resolve())
        waitsForPromise =>
          @task.performRemote().then (result) =>
            expect(result).toBe(Task.Status.Success)

    describe "if _performRequests rejects with a permanent network error", ->
      beforeEach ->
        @task = new ChangeMailTask()
        spyOn(@task, '_performRequests').andReturn(Promise.reject(new APIError(statusCode: 400)))
        spyOn(@task, 'performLocal').andReturn(Promise.resolve())

      it "should set isReverting and call performLocal", ->
        waitsForPromise =>
          @task.performRemote().then (result) =>
            expect(@task.performLocal).toHaveBeenCalled()
            expect(@task._isReverting).toBe(true)

      it "should resolve with Task.Status.Failed after reverting", ->
        waitsForPromise =>
          @task.performRemote().then (result) =>
            expect(result).toBe(Task.Status.Failed)

    describe "if _performRequests rejects with a temporary network error", ->
      beforeEach ->
        @task = new ChangeMailTask()
        spyOn(@task, '_performRequests').andReturn(Promise.reject(new APIError(statusCode: NylasAPI.SampleTemporaryErrorCode)))
        spyOn(@task, 'performLocal').andReturn(Promise.resolve())

      it "should not revert", ->
        waitsForPromise =>
          @task.performRemote().then (result) =>
            expect(@task.performLocal).not.toHaveBeenCalled()
            expect(@task._isReverting).not.toBe(true)

      it "should resolve with Task.Status.Retry", ->
        waitsForPromise =>
          @task.performRemote().then (result) =>
            expect(result).toBe(Task.Status.Retry)


    describe "_performRequests", ->
      beforeEach ->
        @task = new ChangeMailTask()
        @task._restoreValues =
          'A': {}
          'B': {}
          'C': {}
          'A1': {}
        spyOn(@task, 'requestBodyForModel').andCallFake (model) =>
          if model is @threadA
            return {field: 'thread-a-body'}
          if model is @threadB
            return {field: 'thread-b-body'}
          if model is @threadAMesage1
            return {field: 'message-1'}

      it "should call NylasAPI.makeRequest for each model, passing the result of requestBodyForModel", ->
        spyOn(NylasAPI, 'makeRequest').andReturn(Promise.resolve())
        runs ->
          @task._performRequests(Thread, [@threadA, @threadB])
        waitsFor ->
          NylasAPI.makeRequest.callCount is 2
        runs ->
          expect(NylasAPI.makeRequest.calls[0].args[0].body).toEqual({field: 'thread-a-body'})
          expect(NylasAPI.makeRequest.calls[1].args[0].body).toEqual({field: 'thread-b-body'})

      it "should resolve when all of the requests complete", ->
        promises = []
        spyOn(NylasAPI, 'makeRequest').andCallFake ->
          new Promise (resolve, reject) -> promises.push({resolve, reject})

        resolved = false
        runs ->
          @task._performRequests(Thread, [@threadA, @threadB]).then =>
            resolved = true
        waitsFor ->
          NylasAPI.makeRequest.callCount is 2
        runs ->
          expect(resolved).toBe(false)
          promises[0].resolve()
          advanceClock()
          expect(resolved).toBe(false)
          promises[1].resolve()
          advanceClock()
          expect(resolved).toBe(true)

      it "should carry on and resolve if a request 404s, since the NylasAPI manager will clean the object from the cache", ->
        promises = []
        spyOn(NylasAPI, 'makeRequest').andCallFake ->
          new Promise (resolve, reject) -> promises.push({resolve, reject})

        resolved = false
        runs ->
          @task._performRequests(Thread, [@threadA, @threadB]).then =>
            resolved = true
        waitsFor ->
          NylasAPI.makeRequest.callCount is 2
        runs ->
          promises[0].resolve()
          promises[1].reject(new APIError(statusCode: 404))
          advanceClock()
          expect(resolved).toBe(true)

      it "should reject with the request error encountered by any request", ->
        promises = []
        spyOn(NylasAPI, 'makeRequest').andCallFake ->
          new Promise (resolve, reject) -> promises.push({resolve, reject})

        err = null
        runs ->
          @task._performRequests(Thread, [@threadA, @threadB]).catch (error) =>
            err = error
        waitsFor ->
          NylasAPI.makeRequest.callCount is 2
        runs ->
          expect(err).toBe(null)
          promises[0].resolve()
          advanceClock()
          expect(err).toBe(null)
          apiError = new APIError(statusCode: NylasAPI.SampleTemporaryErrorCode)
          promises[1].reject(apiError)
          advanceClock()
          expect(err).toBe(apiError)

      it "should use /threads when the klass provided is Thread", ->
        spyOn(NylasAPI, 'makeRequest').andCallFake ->
          new Promise (resolve, reject) -> #noop
        runs ->
          @task._performRequests(Thread, [@threadA, @threadB])
        waitsFor ->
          NylasAPI.makeRequest.callCount is 2
        runs ->
          path = "/threads/#{@threadA.id}"
          expect(NylasAPI.makeRequest.calls[0].args[0].path).toBe(path)
          expect(NylasAPI.makeRequest.calls[0].args[0].accountId).toBe(@threadA.accountId)

      it "should use /messages when the klass provided is Message", ->
        spyOn(NylasAPI, 'makeRequest').andCallFake ->
          new Promise (resolve, reject) -> #noop
        runs ->
          @task._performRequests(Message, [@threadAMesage1])
        waitsFor ->
          NylasAPI.makeRequest.callCount is 1
        runs ->
          path = "/messages/#{@threadAMesage1.id}"
          expect(NylasAPI.makeRequest.calls[0].args[0].path).toBe(path)
          expect(NylasAPI.makeRequest.calls[0].args[0].accountId).toBe(@threadAMesage1.accountId)

      it "should decrement change counts as requests complete", ->
        spyOn(NylasAPI, 'makeRequest').andCallFake ->
          new Promise (resolve, reject) -> #noop
        spyOn(@task, '_removeLock')
        runs ->
          @task._performRequests(Thread, [@threadAMesage1])
        waitsFor ->
          NylasAPI.makeRequest.callCount is 1
        runs ->
          NylasAPI.makeRequest.calls[0].args[0].beforeProcessing({})
          expect(@task._removeLock).toHaveBeenCalledWith(@threadAMesage1)

      it "should make no more than 10 requests at once", ->
        resolves = []
        spyOn(@task, '_removeLock')
        spyOn(NylasAPI, 'makeRequest').andCallFake ->
          new Promise (resolve, reject) -> resolves.push(resolve)

        threads = []
        threads.push new Thread(id: "#{idx}", subject: idx) for idx in [0..100]
        @task._restoreValues = _.map threads, (t) -> {some: 'data'}
        @task._performRequests(Thread, threads)
        advanceClock()
        expect(resolves.length).toEqual(5)
        advanceClock()
        expect(resolves.length).toEqual(5)
        resolves[0]()
        resolves[1]()
        advanceClock()
        expect(resolves.length).toEqual(7)
        resolves[idx]() for idx in [2...7]
        advanceClock()
        expect(resolves.length).toEqual(12)


      it "should stop making requests after non-404 network errors", ->
        resolves = []
        rejects = []
        spyOn(@task, '_removeLock')
        spyOn(NylasAPI, 'makeRequest').andCallFake ->
          new Promise (resolve, reject) ->
            resolves.push(resolve)
            rejects.push(reject)

        threads = []
        threads.push new Thread(id: "#{idx}", subject: idx) for idx in [0..100]
        @task._restoreValues = _.map threads, (t) -> {some: 'data'}
        @task._performRequests(Thread, threads)
        advanceClock()
        expect(resolves.length).toEqual(5)
        resolves[idx]() for idx in [0...4]
        advanceClock()
        expect(resolves.length).toEqual(9)

        # simulate request failure
        reject = rejects[rejects.length - 1]
        reject(new APIError(statusCode: 400))
        advanceClock()

        # simulate more requests succeeding
        resolves[idx]() for idx in [5...9]
        advanceClock()

        # check that no more requests have been queued
        expect(resolves.length).toEqual(9)

  describe "optimistic object locking", ->
    beforeEach ->
      @task = new ChangeMailTask()
      spyOn(@task, '_performLocalThreads').andReturn(Promise.resolve())
      spyOn(@task, '_lockAll')

    it "increments the locks in performLocal", ->
      waitsForPromise =>
        @task.performLocal().then =>
          expect(@task._lockAll).toHaveBeenCalled()

    describe "when the task is reverting after request failures", ->
      it "should not increment change locks", ->
        @task._isReverting = true
        waitsForPromise =>
          @task.performLocal().then =>
            expect(@task._lockAll).not.toHaveBeenCalled()

    describe "when the task is undoing", ->
      it "should increment change locks", ->
        @task._isUndoTask = true
        @task._restoreValues = {}
        waitsForPromise =>
          @task.performLocal().then =>
            expect(@task._lockAll).toHaveBeenCalled()

    describe "when performRemote is returning Task.Status.Success", ->
      it "should clean up locks", ->
        spyOn(@task, '_performRequests').andReturn(Promise.resolve())
        spyOn(@task, '_ensureLocksRemoved')
        waitsForPromise =>
          @task.performRemote().then =>
            expect(@task._ensureLocksRemoved).toHaveBeenCalled()

    describe "when performRemote is returning Task.Status.Failed after reverting", ->
      it "should clean up locks", ->
        spyOn(@task, '_performRequests').andReturn(Promise.reject(new APIError(statusCode: 400)))
        spyOn(@task, '_ensureLocksRemoved')
        waitsForPromise =>
          @task.performRemote().then =>
            expect(@task._ensureLocksRemoved).toHaveBeenCalled()

    describe "when performRemote is returning Task.Status.Retry", ->
      it "should not clean up locks", ->
        spyOn(@task, '_performRequests').andReturn(Promise.reject(new APIError(statusCode: NylasAPI.SampleTemporaryErrorCode)))
        spyOn(@task, '_ensureLocksRemoved')
        waitsForPromise =>
          @task.performRemote().then =>
            expect(@task._ensureLocksRemoved).not.toHaveBeenCalled()

  describe "_lockAll", ->
    beforeEach ->
      @task = new ChangeMailTask()
      @task.threads = [@threadA, @threadB]
      spyOn(NylasAPI, 'incrementOptimisticChangeCount')

    it "should keep a hash of the items that it locks", ->
      @task._lockAll()
      expect(NylasAPI.incrementOptimisticChangeCount.callCount).toBe(2)
      expect(@task._locked).toEqual('A': 1, 'B': 1)

    it "should not break anything if it's accidentally called twice", ->
      @task._lockAll()
      @task._lockAll()
      expect(NylasAPI.incrementOptimisticChangeCount.callCount).toBe(4)
      expect(@task._locked).toEqual('A': 2, 'B': 2)

  describe "_ensureLocksRemoved", ->
    it "should decrement locks given any aribtrarily messed up lock state and reset the locked array", ->
      @task = new ChangeMailTask()
      @task.threads = [@threadA, @threadB, @threadC]
      spyOn(NylasAPI, 'decrementOptimisticChangeCount')
      @task._locked = {'A': 2, 'B': 2, 'C': 1}
      @task._ensureLocksRemoved()
      expect(NylasAPI.decrementOptimisticChangeCount.callCount).toBe(5)
      expect(NylasAPI.decrementOptimisticChangeCount.calls[0].args[1]).toBe('A')
      expect(NylasAPI.decrementOptimisticChangeCount.calls[1].args[1]).toBe('A')
      expect(NylasAPI.decrementOptimisticChangeCount.calls[2].args[1]).toBe('B')
      expect(NylasAPI.decrementOptimisticChangeCount.calls[3].args[1]).toBe('B')
      expect(NylasAPI.decrementOptimisticChangeCount.calls[4].args[1]).toBe('C')
      expect(@task._locked).toEqual(null)

  describe "createIdenticalTask", ->
    it "should return a copy of the task, but with the objects converted into object ids", ->
      task = new ChangeMailTask()
      task.messages = [@threadAMesage1, @threadAMesage2]
      clone = task.createIdenticalTask()
      expect(clone.messages).toEqual([@threadAMesage1.id, @threadAMesage2.id])

      task = new ChangeMailTask()
      task.threads = [@threadA, @threadB]
      clone = task.createIdenticalTask()
      expect(clone.threads).toEqual([@threadA.id, @threadB.id])

      task = new ChangeMailTask()
      task.threads = [@threadA.id, @threadB.id]
      clone = task.createIdenticalTask()
      expect(clone.threads).toEqual([@threadA.id, @threadB.id])

  describe "createUndoTask", ->
    it "should return a task initialized with _isUndoTask and _restoreValues", ->
      task = new ChangeMailTask()
      task.messages = [@threadAMesage1, @threadAMesage2]
      task._restoreValues = {'A': 'bla'}
      undo = task.createUndoTask()
      expect(undo.messages).toEqual([@threadAMesage1.id, @threadAMesage2.id])
      expect(undo._restoreValues).toBe(task._restoreValues)
      expect(undo._isUndoTask).toBe(true)

    it "should throw if you try to make an undo task of an undo task", ->
      task = new ChangeMailTask()
      task._isUndoTask = true
      expect( -> task.createUndoTask()).toThrow()

    it "should throw if _restoreValues are not availble", ->
      task = new ChangeMailTask()
      task.messages = [@threadAMesage1, @threadAMesage2]
      task._restoreValues = null
      expect( -> task.createUndoTask()).toThrow()

  describe "isDependentTask", ->
    it "should return true if another, older ChangeMailTask involves the same threads", ->
      a = new ChangeMailTask()
      a.threads = ['t1', 't2', 't3']
      a.creationDate = new Date(1000)
      b = new ChangeMailTask()
      b.threads = ['t3', 't4', 't7']
      b.creationDate = new Date(2000)
      c = new ChangeMailTask()
      c.threads = ['t0', 't7']
      c.creationDate = new Date(3000)
      expect(a.isDependentTask(b)).toEqual(false)
      expect(a.isDependentTask(c)).toEqual(false)
      expect(b.isDependentTask(a)).toEqual(true)
      expect(c.isDependentTask(a)).toEqual(false)
      expect(c.isDependentTask(b)).toEqual(true)
