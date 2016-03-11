_ = require 'underscore'

{DatabaseTransaction,
SyncbackDraftTask,
SyncbackMetadataTask,
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
remoteDraft = -> new Message _.extend {}, testData, {clientId: "local-id", serverId: "remoteid1234", threadId: '1234', version: 2}

describe "SyncbackDraftTask", ->
  beforeEach ->
    spyOn(AccountStore, "accountForEmail").andCallFake (email) ->
      return new Account(clientId: 'local-abc123', serverId: 'abc123', emailAddress: email)

    spyOn(DatabaseStore, "run").andCallFake (query) ->
      clientId = query.matcherValueForModelKey('clientId')
      if clientId is "localDraftId" then Promise.resolve(localDraft())
      else if clientId is "remoteDraftId" then Promise.resolve(remoteDraft())
      else if clientId is "missingDraftId" then Promise.resolve()
      else return Promise.resolve()

    spyOn(NylasAPI, 'incrementRemoteChangeLock')
    spyOn(NylasAPI, 'decrementRemoteChangeLock')
    spyOn(DatabaseTransaction.prototype, "persistModel").andReturn Promise.resolve()

  describe "queueing multiple tasks", ->
    beforeEach ->
      @taskA = new SyncbackDraftTask("draft-123")
      @taskB = new SyncbackDraftTask("draft-123")
      @taskC = new SyncbackDraftTask("draft-123")
      @taskOther = new SyncbackDraftTask("draft-456")

      @taskA.sequentialId = 0
      @taskB.sequentialId = 1
      @taskC.sequentialId = 2
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

    it "should apply the server ID, thread ID and version to the draft", ->
      task = new SyncbackDraftTask("localDraftId")
      waitsForPromise =>
        task.performRemote().then ->
          expect(DatabaseTransaction.prototype.persistModel).toHaveBeenCalled()
          saved = DatabaseTransaction.prototype.persistModel.calls[0].args[0]
          remote = remoteDraft()
          expect(saved.threadId).toEqual(remote.threadId)
          expect(saved.serverId).toEqual(remote.serverId)
          expect(saved.version).toEqual(remote.version)

    it "should pass returnsModel:false so that the draft can be manually removed/added to the database, accounting for its ID change", ->
      task = new SyncbackDraftTask("localDraftId")
      waitsForPromise =>
        task.performRemote().then ->
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.returnsModel).toBe(false)

    it "should not save metadata associated to the draft when the draft has been already saved to the api", ->
      draft = remoteDraft()
      draft.pluginMetadata = [{pluginId: 1, value: {a: 1}}]
      task = new SyncbackDraftTask(draft.clientId)
      spyOn(task, 'getLatestLocalDraft').andReturn Promise.resolve(draft)
      spyOn(Actions, 'queueTask')
      waitsForPromise =>
        task.updateLocalDraft(draft).then =>
          expect(Actions.queueTask).not.toHaveBeenCalled()

    it "should save metadata associated to the draft when the draft is syncbacked for the first time", ->
      draft = localDraft()
      draft.pluginMetadata = [{pluginId: 1, value: {a: 1}}]
      task = new SyncbackDraftTask(draft.clientId)
      spyOn(task, 'getLatestLocalDraft').andReturn Promise.resolve(draft)
      spyOn(Actions, 'queueTask')
      waitsForPromise =>
        task.updateLocalDraft(draft).then =>
          metadataTask = Actions.queueTask.mostRecentCall.args[0]
          expect(metadataTask instanceof SyncbackMetadataTask).toBe true
          expect(metadataTask.clientId).toEqual draft.clientId
          expect(metadataTask.modelClassName).toEqual 'Message'
          expect(metadataTask.pluginId).toEqual 1

    describe 'when `from` value does not match the account associated to the draft', ->
      beforeEach ->
        @serverId = 'remote123'
        @draft = remoteDraft()
        @draft.serverId = 'remote123'
        @draft.from = [{email: 'another@email.com'}]
        @task = new SyncbackDraftTask(@draft.clientId)
        jasmine.unspy(AccountStore, 'accountForEmail')
        spyOn(AccountStore, "accountForEmail").andReturn {id: 'other-account'}
        spyOn(Actions, "queueTask")
        spyOn(@task, 'getLatestLocalDraft').andReturn Promise.resolve(@draft)

      it "should delete the remote draft if it was already saved", ->
        waitsForPromise =>
          @task.checkDraftFromMatchesAccount(@draft).then =>
            expect(NylasAPI.makeRequest).toHaveBeenCalled()
            params = NylasAPI.makeRequest.mostRecentCall.args[0]
            expect(params.method).toEqual "DELETE"
            expect(params.path).toEqual "/drafts/#{@serverId}"

      it "should increment the change tracker for the deleted serverId, preventing any further deltas about the draft", ->
        waitsForPromise =>
          @task.checkDraftFromMatchesAccount(@draft).then =>
            expect(NylasAPI.incrementRemoteChangeLock).toHaveBeenCalledWith(Message, 'remote123')

      it "should change the accountId and clear server fields", ->
        waitsForPromise =>
          @task.checkDraftFromMatchesAccount(@draft).then (updatedDraft) =>
            expect(updatedDraft.serverId).toBeUndefined()
            expect(updatedDraft.version).toBeUndefined()
            expect(updatedDraft.threadId).toBeUndefined()
            expect(updatedDraft.replyToMessageId).toBeUndefined()
            expect(updatedDraft.accountId).toEqual 'other-account'

      it "should syncback any metadata associated with the original draft", ->
        @draft.pluginMetadata = [{pluginId: 1, value: {a: 1}}]
        @task = new SyncbackDraftTask(@draft.clientId)
        spyOn(@task, 'getLatestLocalDraft').andReturn Promise.resolve(@draft)
        spyOn(@task, 'saveDraft').andCallFake (d) -> Promise.resolve(d)
        waitsForPromise =>
          @task.performRemote().then =>
            metadataTask = Actions.queueTask.mostRecentCall.args[0]
            expect(metadataTask instanceof SyncbackMetadataTask).toBe true
            expect(metadataTask.clientId).toEqual @draft.clientId
            expect(metadataTask.modelClassName).toEqual 'Message'
            expect(metadataTask.pluginId).toEqual 1


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

    NylasAPI.PermanentErrorCodes.forEach (code) ->
      it "fails on API status code #{code}", ->
        stubAPI(code, "PUT")
        waitsForPromise =>
          @task.performRemote().then ([status, err]) =>
            expect(status).toBe Task.Status.Failed
            expect(@task.getLatestLocalDraft).toHaveBeenCalled()
            expect(@task.getLatestLocalDraft.calls.length).toBe 1
            expect(err.statusCode).toBe code

    [NylasAPI.TimeoutErrorCode].forEach (code) ->
      it "retries on status code #{code}", ->
        stubAPI(code, "PUT")
        waitsForPromise =>
          @task.performRemote().then (status) =>
            expect(status).toBe Task.Status.Retry

    it "fails on other JavaScript errors", ->
      spyOn(NylasAPI, "makeRequest").andCallFake -> Promise.reject(new TypeError())
      waitsForPromise =>
        @task.performRemote().then ([status, err]) =>
          expect(status).toBe Task.Status.Failed
          expect(@task.getLatestLocalDraft).toHaveBeenCalled()
          expect(@task.getLatestLocalDraft.calls.length).toBe 1
