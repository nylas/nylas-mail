_ = require 'underscore'
{APIError,
 Actions,
 DatabaseStore,
 DatabaseTransaction,
 Message,
 Task,
 TaskQueue,
 SendDraftTask,
 SyncbackDraftTask,
 FileUploadTask,
 NylasAPI,
 SoundRegistry} = require 'nylas-exports'

DBt = DatabaseTransaction.prototype

describe "SendDraftTask", ->
  beforeEach ->
    ## TODO FIXME: If we don't spy on DatabaseStore._query, then
    # `DatabaseStore.inTransaction` will never complete and cause all
    # tests that depend on transactions to hang.
    #
    # @_query("BEGIN IMMEDIATE TRANSACTION") never resolves because
    # DatabaseStore._query never runs because the @_open flag is always
    # false because we never setup the DB when `NylasEnv.inSpecMode` is
    # true.
    spyOn(DatabaseStore, '_query').andCallFake => Promise.resolve([])

  describe "isDependentTask", ->
    it "is not dependent on any pending SyncbackDraftTasks", ->
      @draftA = new Message
        version: '1'
        clientId: 'localid-A'
        serverId: '1233123AEDF1'
        accountId: 'A12ADE'
        subject: 'New Draft'
        draft: true
        to:
          name: 'Dummy'
          email: 'dummy@nylas.com'

      @draftB = new Message
        version: '1'
        clientId: 'localid-B'
        serverId: '1233OTHERDRAFT'
        accountId: 'A12ADE'
        subject: 'New Draft'
        draft: true
        to:
          name: 'Dummy'
          email: 'dummy@nylas.com'

      @saveA = new SyncbackDraftTask('localid-A')
      @saveB = new SyncbackDraftTask('localid-B')
      @sendA = new SendDraftTask('localid-A')

      expect(@sendA.isDependentTask(@saveA)).toBe(false)

  describe "performLocal", ->
    it "throws an error if we we don't pass a draftClientId", ->
      badTask = new SendDraftTask()
      badTask.performLocal()
        .then ->
          throw new Error("Shouldn't succeed")
        .catch (err) ->
          expect(err.message).toBe "Attempt to call SendDraftTask.performLocal without @draftClientId."

    it "finds the message and saves a backup copy of it", ->
      draft = new Message
        clientId: "local-123"
        serverId: "server-123"
        draft: true

      calledBody = "ERROR: The body wasn't included!"
      spyOn(DatabaseStore, "findBy").andCallFake ->
        then: -> throw new Error("You must include the body!")
        include: (body) ->
          calledBody = body
          return Promise.resolve(draft)

      task = new SendDraftTask('local-123')
      waitsForPromise => task.performLocal().then =>
        expect(task.backupDraft).toBeDefined()
        expect(task.backupDraft.clientId).toBe "local-123"
        expect(task.backupDraft.serverId).toBe "server-123"
        expect(task.backupDraft).not.toBe draft # It's a clone
        expect(calledBody).toBe Message.attributes.body

  describe "performRemote", ->
    beforeEach ->
      @accountId = "a123"
      @draftClientId = "local-123"
      @serverMessageId = '1233123AEDF1'

      @response =
        version: 2
        id: @serverMessageId
        account_id: @accountId
        subject: 'New Draft'
        body: 'hello world'
        to:
          name: 'Dummy'
          email: 'dummy@nylas.com'

      spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
        options.success?(@response)
        Promise.resolve(@response)
      spyOn(DBt, 'unpersistModel').andCallFake (draft) ->
        Promise.resolve()
      spyOn(DBt, 'persistModel').andCallFake (draft) ->
        Promise.resolve()
      spyOn(SoundRegistry, "playSound")
      spyOn(Actions, "postNotification")
      spyOn(Actions, "sendDraftSuccess")
      spyOn(NylasEnv, "emitError")

    runFetchLatestDraftTests = ->
      it "fetches the draft object from the DB", ->
        waitsForPromise => @task._fetchLatestDraft().then (model) =>
          expect(model).toBe @draft
          expect(@task.draftAccountId).toBe @draft.accountId
          expect(@task.draftServerId).toBe @draft.serverId
          expect(@task.draftVersion).toBe @draft.version

      it "throws a `NotFoundError` if the model is blank", ->
        spyOn(@task, "_notifyUserOfError")
        spyOn(@task, "_permanentError").andCallThrough()
        @draftResolver = -> Promise.resolve(null)
        waitsForPromise => @task.performRemote().then =>
          expect(DBt.persistModel.callCount).toBe 1
          expect(DBt.persistModel).toHaveBeenCalledWith(@backupDraft)
          expect(@task._permanentError).toHaveBeenCalled()

      it "throws a `NotFoundError` if findBy fails", ->
        spyOn(@task, "_notifyUserOfError")
        spyOn(@task, "_permanentError").andCallThrough()
        @draftResolver = -> Promise.reject(new Error("Test Problem"))
        waitsForPromise => @task.performRemote().then =>
          expect(DBt.persistModel.callCount).toBe 1
          expect(DBt.persistModel).toHaveBeenCalledWith(@backupDraft)
          expect(@task._permanentError).toHaveBeenCalled()

    # All of these are run in both the context of a saved draft and a new
    # draft.
    runMakeSendRequestTests = ->
      it "makes a send request with the correct data", ->
        @task.draftAccountId = @accountId
        waitsForPromise => @task._makeSendRequest(@draft).then =>
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          reqArgs = NylasAPI.makeRequest.calls[0].args[0]
          expect(reqArgs.accountId).toBe @accountId
          expect(reqArgs.body).toEqual @draft.toJSON()

      it "should pass returnsModel:false", ->
        waitsForPromise => @task._makeSendRequest(@draft).then ->
          expect(NylasAPI.makeRequest.calls.length).toBe(1)
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.returnsModel).toBe(false)

      it "should always send the draft body in the request body (joined attribute check)", ->
        waitsForPromise =>
          @task._makeSendRequest(@draft).then =>
            expect(NylasAPI.makeRequest.calls.length).toBe(1)
            options = NylasAPI.makeRequest.mostRecentCall.args[0]
            expect(options.body.body).toBe('hello world')

      it "should start an API request to /send", -> waitsForPromise =>
        @task._makeSendRequest(@draft).then =>
          expect(NylasAPI.makeRequest.calls.length).toBe(1)
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.path).toBe("/send")
          expect(options.method).toBe('POST')

      it "retries the task if 'Invalid message public id'", ->
        jasmine.unspy(NylasAPI, "makeRequest")
        spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
          if options.body.reply_to_message_id
            err = new APIError(body: "Invalid message public id")
            Promise.reject(err)
          else
            options.success?(@response)
            Promise.resolve(@response)

        @draft.replyToMessageId = "reply-123"
        @draft.threadId = "thread-123"
        waitsForPromise => @task._makeSendRequest(@draft).then =>
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          expect(NylasAPI.makeRequest.callCount).toEqual 2
          req1 = NylasAPI.makeRequest.calls[0].args[0]
          req2 = NylasAPI.makeRequest.calls[1].args[0]
          expect(req1.body.reply_to_message_id).toBe "reply-123"
          expect(req1.body.thread_id).toBe "thread-123"

          expect(req2.body.reply_to_message_id).toBe null
          expect(req2.body.thread_id).toBe "thread-123"

      it "retries the task if 'Invalid message public id'", ->
        jasmine.unspy(NylasAPI, "makeRequest")
        spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
          if options.body.reply_to_message_id
            err = new APIError(body: "Invalid thread")
            Promise.reject(err)
          else
            options.success?(@response)
            Promise.resolve(@response)

        @draft.replyToMessageId = "reply-123"
        @draft.threadId = "thread-123"
        waitsForPromise => @task._makeSendRequest(@draft).then =>
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          expect(NylasAPI.makeRequest.callCount).toEqual 2
          req1 = NylasAPI.makeRequest.calls[0].args[0]
          req2 = NylasAPI.makeRequest.calls[1].args[0]
          expect(req1.body.reply_to_message_id).toBe "reply-123"
          expect(req1.body.thread_id).toBe "thread-123"

          expect(req2.body.reply_to_message_id).toBe null
          expect(req2.body.thread_id).toBe null

    runSaveNewMessageTests = ->
      it "should write the saved message to the database with the same client ID", ->
        waitsForPromise =>
          @task._saveNewMessage(@response).then =>
            expect(DBt.persistModel).toHaveBeenCalled()
            expect(DBt.persistModel.mostRecentCall.args[0].clientId).toEqual(@draftClientId)
            expect(DBt.persistModel.mostRecentCall.args[0].serverId).toEqual(@serverMessageId)
            expect(DBt.persistModel.mostRecentCall.args[0].draft).toEqual(false)

    runNotifySuccess = ->
      it "should notify the draft was sent", ->
        waitsForPromise => @task.performRemote().then =>
          args = Actions.sendDraftSuccess.calls[0].args[0]
          expect(args.draftClientId).toBe @draftClientId

      it "get an object back on success", ->
        waitsForPromise => @task.performRemote().then =>
          args = Actions.sendDraftSuccess.calls[0].args[0]
          expect(args.newMessage.id).toBe @serverMessageId

      it "should play a sound", ->
        spyOn(NylasEnv.config, "get").andReturn true
        waitsForPromise => @task.performRemote().then ->
          expect(NylasEnv.config.get).toHaveBeenCalledWith("core.sending.sounds")
          expect(SoundRegistry.playSound).toHaveBeenCalledWith("send")

      it "shouldn't play a sound if the config is disabled", ->
        spyOn(NylasEnv.config, "get").andReturn false
        waitsForPromise => @task.performRemote().then ->
          expect(NylasEnv.config.get).toHaveBeenCalledWith("core.sending.sounds")
          expect(SoundRegistry.playSound).not.toHaveBeenCalled()

    runIntegrativeWithErrors = ->
      describe "when there are errors", ->
        beforeEach ->
          spyOn(@task, "_notifyUserOfError")
          jasmine.unspy(NylasAPI, "makeRequest")

        it "notifies of a permanent error of misc error types", ->
          ## DB error
          thrownError = null
          jasmine.unspy(DBt, "persistModel")
          spyOn(DBt, "persistModel").andCallFake =>
            thrownError = new Error('db error')
            throw thrownError
          waitsForPromise =>
            @task.performRemote().then (status) =>
              expect(status[0]).toBe Task.Status.Failed
              expect(status[1]).toBe thrownError
              expect(@task._notifyUserOfError).toHaveBeenCalled()
              expect(NylasEnv.emitError).toHaveBeenCalled()

        it "notifies of a permanent error on 500 errors", ->
          thrownError = new APIError(statusCode: 500, body: "err")
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            Promise.reject(thrownError)
          waitsForPromise => @task.performRemote().then (status) =>
            expect(status[0]).toBe Task.Status.Failed
            expect(status[1]).toBe thrownError
            expect(@task._notifyUserOfError).toHaveBeenCalled()
            expect(NylasEnv.emitError).not.toHaveBeenCalled()

        it "notifies us and users of a permanent error on 400 errors", ->
          thrownError = new APIError(statusCode: 400, body: "err")
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            Promise.reject(thrownError)
          waitsForPromise => @task.performRemote().then (status) =>
            expect(status[0]).toBe Task.Status.Failed
            expect(status[1]).toBe thrownError
            expect(@task._notifyUserOfError).toHaveBeenCalled()
            expect(NylasEnv.emitError).toHaveBeenCalled()

        it "notifies of a permanent error on timeouts", ->
          thrownError = new APIError(statusCode: NylasAPI.TimeoutErrorCode, body: "err")
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            Promise.reject(thrownError)
          waitsForPromise => @task.performRemote().then (status) =>
            expect(status[0]).toBe Task.Status.Failed
            expect(status[1]).toBe thrownError
            expect(@task._notifyUserOfError).toHaveBeenCalled()
            expect(NylasEnv.emitError).not.toHaveBeenCalled()

        it "retries for other error types", ->
          thrownError = new APIError(statusCode: 402, body: "err")
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            Promise.reject(thrownError)
          waitsForPromise => @task.performRemote().then (status) =>
            expect(status).toBe Task.Status.Retry
            expect(@task._notifyUserOfError).not.toHaveBeenCalled()
            expect(NylasEnv.emitError).not.toHaveBeenCalled()

        it "notifies the user that the required file upload failed", ->
          fileUploadTask = new FileUploadTask('/dev/null', 'local-1234')
          @task.onDependentTaskError(fileUploadTask, new Error("Oh no"))
          expect(@task._notifyUserOfError).toHaveBeenCalled()
          expect(@task._notifyUserOfError.calls.length).toBe 1

        describe "checking the promise chain halts on errors", ->
          beforeEach ->
            spyOn(@task,"_makeSendRequest").andCallThrough()
            spyOn(@task,"_saveNewMessage").andCallThrough()
            spyOn(@task,"_deleteRemoteDraft").andCallThrough()
            spyOn(@task,"_notifySuccess").andCallThrough()
            spyOn(@task,"_onError").andCallThrough()

            @expectBlockedChain = =>
              expect(@task._makeSendRequest).toHaveBeenCalled()
              expect(@task._saveNewMessage).not.toHaveBeenCalled()
              expect(@task._deleteRemoteDraft).not.toHaveBeenCalled()
              expect(@task._notifySuccess).not.toHaveBeenCalled()
              expect(@task._onError).toHaveBeenCalled()

          it "halts on 500s", ->
            thrownError = new APIError(statusCode: 500, body: "err")
            spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
              Promise.reject(thrownError)
            waitsForPromise => @task.performRemote().then (status) =>
              @expectBlockedChain()

          it "halts on 400s", ->
            thrownError = new APIError(statusCode: 400, body: "err")
            spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
              Promise.reject(thrownError)
            waitsForPromise => @task.performRemote().then (status) =>
              @expectBlockedChain()

          it "halts on other errors", ->
            thrownError = new Error("oh no")
            spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
              Promise.reject(thrownError)
            waitsForPromise => @task.performRemote().then (status) =>
              @expectBlockedChain()

          it "dosn't halt on success", ->
            spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
              options.success?(@response)
              Promise.resolve(@response)
            waitsForPromise => @task.performRemote().then (status) =>
              expect(@task._makeSendRequest).toHaveBeenCalled()
              expect(@task._saveNewMessage).toHaveBeenCalled()
              expect(@task._deleteRemoteDraft).toHaveBeenCalled()
              expect(@task._notifySuccess).toHaveBeenCalled()
              expect(@task._onError).not.toHaveBeenCalled()


    describe "with a new draft", ->
      beforeEach ->
        @draft = new Message
          version: 1
          clientId: @draftClientId
          accountId: @accountId
          subject: 'New Draft'
          draft: true
          body: 'hello world'
        @task = new SendDraftTask(@draftClientId)
        @backupDraft = @draft.clone()
        @task.backupDraft = @backupDraft # Since performLocal doesn't run
        @draftResolver = -> Promise.resolve(@draft)
        @calledBody = "ERROR: The body wasn't included!"
        spyOn(DatabaseStore, "findBy").andCallFake =>
          include: (body) =>
            @calledBody = body
            return @draftResolver()

      it "can complete a full performRemote", -> waitsForPromise =>
        @task.performRemote().then (status) ->
          expect(status).toBe Task.Status.Success

      runFetchLatestDraftTests.call(@)
      runMakeSendRequestTests.call(@)
      runSaveNewMessageTests.call(@)

      it "shouldn't attempt to delete a draft", -> waitsForPromise =>
        expect(@task.draftServerId).not.toBeDefined()
        @task._deleteRemoteDraft().then =>
          expect(NylasAPI.makeRequest).not.toHaveBeenCalled()

      runNotifySuccess.call(@)
      runIntegrativeWithErrors.call(@)

      it "should locally convert the draft to a message on send", ->
        expect(@draft.clientId).toBe @draftClientId
        expect(@draft.serverId).toBeUndefined()
        waitsForPromise => @task.performRemote().then =>
          expect(DBt.persistModel).toHaveBeenCalled()
          model = DBt.persistModel.calls[0].args[0]
          expect(model.clientId).toBe @draftClientId
          expect(model.serverId).toBe @serverMessageId
          expect(model.draft).toBe false


    describe "with an existing persisted draft", ->
      beforeEach ->
        @draftServerId = 'server-123'
        @draft = new Message
          version: 1
          clientId: @draftClientId
          serverId: @draftServerId
          accountId: @accountId
          subject: 'New Draft'
          draft: true
          body: 'hello world'
          to:
            name: 'Dummy'
            email: 'dummy@nylas.com'
        @task = new SendDraftTask(@draftClientId)
        @backupDraft = @draft.clone()
        @task.backupDraft = @backupDraft # Since performLocal doesn't run
        @draftResolver = -> Promise.resolve(@draft)
        @calledBody = "ERROR: The body wasn't included!"
        spyOn(DatabaseStore, "findBy").andCallFake =>
          then: -> throw new Error("You must include the body!")
          include: (body) =>
            @calledBody = body
            return @draftResolver()

      it "can complete a full performRemote", -> waitsForPromise =>
        @task.performRemote().then (status) ->
          expect(status).toBe Task.Status.Success

      runFetchLatestDraftTests.call(@)
      runMakeSendRequestTests.call(@)
      runSaveNewMessageTests.call(@)

      it "should make a request to delete a draft", ->
        waitsForPromise => @task._fetchLatestDraft().then(@task._deleteRemoteDraft).then =>
          expect(@task.draftServerId).toBe @draftServerId
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          expect(NylasAPI.makeRequest.callCount).toBe 1
          req = NylasAPI.makeRequest.calls[0].args[0]
          expect(req.path).toBe "/drafts/#{@draftServerId}"
          expect(req.accountId).toBe @accountId
          expect(req.method).toBe "DELETE"
          expect(req.returnsModel).toBe false

      it "should continue if the request failes", ->
        jasmine.unspy(NylasAPI, "makeRequest")
        spyOn(console, "error")
        spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
          err = new APIError(body: "Boo", statusCode: 500)
          Promise.reject(err)
        waitsForPromise => @task._fetchLatestDraft().then(@task._deleteRemoteDraft).then =>
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          expect(NylasAPI.makeRequest.callCount).toBe 1
          expect(console.error).toHaveBeenCalled()
        .catch =>
          throw new Error("Shouldn't fail the promise")

      runNotifySuccess.call(@)
      runIntegrativeWithErrors.call(@)

      it "should locally convert the existing draft to a message on send", ->
        expect(@draft.clientId).toBe @draftClientId
        expect(@draft.serverId).toBe "server-123"
        waitsForPromise => @task.performRemote().then =>
          expect(DBt.persistModel).toHaveBeenCalled()
          model = DBt.persistModel.calls[0].args[0]
          expect(model.clientId).toBe @draftClientId
          expect(model.serverId).toBe @serverMessageId
          expect(model.draft).toBe false
