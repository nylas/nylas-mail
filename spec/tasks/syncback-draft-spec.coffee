_ = require 'underscore'

{DatabaseTransaction,
SyncbackDraftTask,
DatabaseStore,
AccountStore,
TaskQueue,
Contact,
Message,
Account,
Actions,
Task,
APIError,
NylasAPI} = require 'nylas-exports'

inboxError =
  message: "No draft with public id bvn4aydxuyqlbmzowh4wraysg",
  type: "invalid_request_error"

testData =
  to: [new Contact(name: "Ben Gotow", email: "ben@nylas.com")]
  from: [new Contact(name: "Evan Morikawa", email: "evan@nylas.com")]
  date: new Date
  draft: true
  subject: "Test"
  accountId: "abc123"
  body: '<body>123</body>'

localDraft = -> new Message _.extend {}, testData, {clientId: "local-id"}
remoteDraft = -> new Message _.extend {}, testData, {clientId: "local-id", serverId: "remoteid1234"}

describe "SyncbackDraftTask", ->
  beforeEach ->
    spyOn(AccountStore, "accountForEmail").andCallFake (email) ->
      return new Account(clientId: 'local-abc123', serverId: 'abc123')

    spyOn(DatabaseStore, "run").andCallFake (query) ->
      clientId = query.matcherValueForModelKey('clientId')
      if clientId is "localDraftId" then Promise.resolve(localDraft())
      else if clientId is "remoteDraftId" then Promise.resolve(remoteDraft())
      else if clientId is "missingDraftId" then Promise.resolve()
      else return Promise.resolve()

    spyOn(DatabaseTransaction.prototype, "persistModel").andCallFake ->
      Promise.resolve()

  describe "queueing multiple tasks", ->
    beforeEach ->
      @taskA = new SyncbackDraftTask("draft-123")
      @taskB = new SyncbackDraftTask("draft-123")
      @taskC = new SyncbackDraftTask("draft-123")
      @taskOther = new SyncbackDraftTask("draft-456")

      now = Date.now()
      @taskA.creationDate = now - 20
      @taskB.creationDate = now - 10
      @taskC.creationDate = now
      TaskQueue._queue = []

    it "dequeues other SyncbackDraftTasks that haven't started yet", ->
      # Task A is taking forever, B is waiting on it, and C gets queued.
      [@taskA, @taskB, @taskOther].forEach (t) ->
        t.queueState.localComplete = true

      # taskA has already started This should NOT get dequeued
      @taskA.queueState.isProcessing = true

      # taskB hasn't started yet! This should get dequeued
      @taskB.queueState.isProcessing = false

      # taskOther, while unstarted, doesn't match the draftId and should
      # not get dequeued
      @taskOther.queueState.isProcessing = false

      TaskQueue._queue = [@taskA, @taskB, @taskOther]
      spyOn(@taskC, "runLocal").andReturn Promise.resolve()

      TaskQueue.enqueue(@taskC)

      # Note that taskB is gone, taskOther was untouched, and taskC was
      # added.
      expect(TaskQueue._queue).toEqual = [@taskA, @taskOther, @taskC]

      expect(@taskC.runLocal).toHaveBeenCalled()

    it "waits for any other inflight tasks to finish or error", ->
      @taskA.queueState.localComplete = true
      @taskA.queueState.isProcessing = true
      @taskB.queueState.localComplete = true
      spyOn(@taskB, "runRemote").andReturn Promise.resolve()

      TaskQueue._queue = [@taskA, @taskB]

      # Since taskA has isProcessing set to true, it will just be passed
      # over. We expect taskB to fail the `_taskIsBlocked` test
      TaskQueue._processQueue()
      advanceClock(100)
      expect(TaskQueue._queue).toEqual [@taskA, @taskB]
      expect(@taskA.queueState.isProcessing).toBe true
      expect(@taskB.queueState.isProcessing).toBe false
      expect(@taskB.runRemote).not.toHaveBeenCalled()

  describe "performRemote", ->
    beforeEach ->
      spyOn(NylasAPI, 'makeRequest').andCallFake (opts) ->
        Promise.resolve(remoteDraft().toJSON())

    it "does nothing if no draft can be found in the db", ->
      task = new SyncbackDraftTask("missingDraftId")
      waitsForPromise =>
        task.performRemote().then ->
          expect(NylasAPI.makeRequest).not.toHaveBeenCalled()

    it "should start an API request with the Message JSON", ->
      task = new SyncbackDraftTask("localDraftId")
      waitsForPromise =>
        task.performRemote().then ->
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          reqBody = NylasAPI.makeRequest.mostRecentCall.args[0].body
          expect(reqBody.subject).toEqual testData.subject
          expect(reqBody.body).toEqual testData.body

    it "should do a PUT when the draft has already been saved", ->
      task = new SyncbackDraftTask("remoteDraftId")
      waitsForPromise =>
        task.performRemote().then ->
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.path).toBe("/drafts/remoteid1234")
          expect(options.accountId).toBe("abc123")
          expect(options.method).toBe('PUT')

    it "should do a POST when the draft is unsaved", ->
      task = new SyncbackDraftTask("localDraftId")
      waitsForPromise =>
        task.performRemote().then ->
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.path).toBe("/drafts")
          expect(options.accountId).toBe("abc123")
          expect(options.method).toBe('POST')

    it "should pass returnsModel:false so that the draft can be manually removed/added to the database, accounting for its ID change", ->
      task = new SyncbackDraftTask("localDraftId")
      waitsForPromise =>
        task.performRemote().then ->
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.returnsModel).toBe(false)

  describe "When the api throws errors", ->
    stubAPI = (code, method) ->
      spyOn(NylasAPI, "makeRequest").andCallFake (opts) ->
        Promise.reject(
          new APIError
            error: inboxError
            response:{statusCode: code}
            body: inboxError
            requestOptions: method: method
        )

    beforeEach ->
      @task = new SyncbackDraftTask("removeDraftId")
      spyOn(@task, "getLatestLocalDraft").andCallFake -> Promise.resolve(remoteDraft())

    [500, 400, 0].forEach (code) ->
      it "Fails on #{code} errors when we're PUT-ing", ->
        stubAPI(code, "PUT")
        waitsForPromise =>
          @task.performRemote().then ([status, err]) =>
            expect(status).toBe Task.Status.Failed
            expect(@task.getLatestLocalDraft).toHaveBeenCalled()
            expect(@task.getLatestLocalDraft.calls.length).toBe 1
            expect(err.statusCode).toBe code

    it "Fails on unknown errors", ->
      spyOn(NylasAPI, "makeRequest").andCallFake -> Promise.reject(new APIError())
      waitsForPromise =>
        @task.performRemote().then ([status, err]) =>
          expect(status).toBe Task.Status.Failed
          expect(@task.getLatestLocalDraft).toHaveBeenCalled()
          expect(@task.getLatestLocalDraft.calls.length).toBe 1
