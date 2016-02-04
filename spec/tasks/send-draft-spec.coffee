_ = require 'underscore'
{APIError,
 Actions,
 DatabaseStore,
 DatabaseTransaction,
 Message,
 Contact,
 Task,
 TaskQueue,
 SendDraftTask,
 SyncbackDraftTask,
 NylasAPI,
 SoundRegistry} = require 'nylas-exports'

DBt = DatabaseTransaction.prototype

describe "SendDraftTask", ->

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

      @saveA = new SyncbackDraftTask(@draftA, [])
      @sendA = new SendDraftTask(@draftA, [])

      expect(@sendA.isDependentTask(@saveA)).toBe(false)

  describe "performLocal", ->
    it "throws an error if we we don't pass a draft", ->
      badTask = new SendDraftTask()
      badTask.performLocal()
        .then ->
          throw new Error("Shouldn't succeed")
        .catch (err) ->
          expect(err.message).toBe "SendDraftTask - must be provided a draft."

    it "throws an error if we we don't pass uploads", ->
      message = new Message()
      message.uploads = null
      badTask = new SendDraftTask(message)
      badTask.performLocal()
        .then ->
          throw new Error("Shouldn't succeed")
        .catch (err) ->
          expect(err.message).toBe "SendDraftTask - must be provided an array of uploads."

  describe "performRemote", ->
    beforeEach ->
      @response =
        version: 2
        id: '1233123AEDF1'
        account_id: TEST_ACCOUNT_ID
        from: [new Contact(email: TEST_ACCOUNT_EMAIL)]
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
      spyOn(NylasEnv, "reportError")

    sharedTests = =>
      it "makes a send request with the correct data", ->
        waitsForPromise => @task._sendAndCreateMessage().then =>
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          reqArgs = NylasAPI.makeRequest.calls[0].args[0]
          expect(reqArgs.accountId).toBe TEST_ACCOUNT_ID
          expect(reqArgs.body).toEqual @draft.toJSON()

      it "should pass returnsModel:false", ->
        waitsForPromise => @task._sendAndCreateMessage().then ->
          expect(NylasAPI.makeRequest.calls.length).toBe(1)
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.returnsModel).toBe(false)

      it "should always send the draft body in the request body (joined attribute check)", ->
        waitsForPromise =>
          @task._sendAndCreateMessage().then =>
            expect(NylasAPI.makeRequest.calls.length).toBe(1)
            options = NylasAPI.makeRequest.mostRecentCall.args[0]
            expect(options.body.body).toBe('hello world')

      it "should start an API request to /send", -> waitsForPromise =>
        @task._sendAndCreateMessage().then =>
          expect(NylasAPI.makeRequest.calls.length).toBe(1)
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.path).toBe("/send")
          expect(options.method).toBe('POST')

      it "should write the saved message to the database with the same client ID", ->
        waitsForPromise =>
          @task._sendAndCreateMessage().then =>
            expect(DBt.persistModel).toHaveBeenCalled()
            expect(DBt.persistModel.mostRecentCall.args[0].clientId).toEqual(@draft.clientId)
            expect(DBt.persistModel.mostRecentCall.args[0].serverId).toEqual(@response.id)
            expect(DBt.persistModel.mostRecentCall.args[0].draft).toEqual(false)

      it "should notify the draft was sent", ->
        waitsForPromise => @task.performRemote().then =>
          args = Actions.sendDraftSuccess.calls[0].args[0]
          expect(args.draftClientId).toBe @draft.clientId

      it "get an object back on success", ->
        waitsForPromise => @task.performRemote().then =>
          args = Actions.sendDraftSuccess.calls[0].args[0]

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

      describe "when there are errors", ->
        beforeEach ->
          spyOn(Actions, 'draftSendingFailed')
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
              expect(Actions.draftSendingFailed).toHaveBeenCalled()
              expect(NylasEnv.reportError).toHaveBeenCalled()

        it "retries the task if 'Invalid message public id'", ->
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            if options.body.reply_to_message_id
              err = new APIError(body: "Invalid message public id")
              Promise.reject(err)
            else
              options.success?(@response)
              Promise.resolve(@response)

          @draft.replyToMessageId = "reply-123"
          @draft.threadId = "thread-123"
          waitsForPromise => @task._sendAndCreateMessage(@draft).then =>
            expect(NylasAPI.makeRequest).toHaveBeenCalled()
            expect(NylasAPI.makeRequest.callCount).toEqual 2
            req1 = NylasAPI.makeRequest.calls[0].args[0]
            req2 = NylasAPI.makeRequest.calls[1].args[0]
            expect(req1.body.reply_to_message_id).toBe "reply-123"
            expect(req1.body.thread_id).toBe "thread-123"

            expect(req2.body.reply_to_message_id).toBe null
            expect(req2.body.thread_id).toBe "thread-123"

        it "retries the task if 'Invalid message public id'", ->
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            if options.body.reply_to_message_id
              err = new APIError(body: "Invalid thread")
              Promise.reject(err)
            else
              options.success?(@response)
              Promise.resolve(@response)

          @draft.replyToMessageId = "reply-123"
          @draft.threadId = "thread-123"
          waitsForPromise => @task._sendAndCreateMessage(@draft).then =>
            expect(NylasAPI.makeRequest).toHaveBeenCalled()
            expect(NylasAPI.makeRequest.callCount).toEqual 2
            req1 = NylasAPI.makeRequest.calls[0].args[0]
            req2 = NylasAPI.makeRequest.calls[1].args[0]
            expect(req1.body.reply_to_message_id).toBe "reply-123"
            expect(req1.body.thread_id).toBe "thread-123"

            expect(req2.body.reply_to_message_id).toBe null
            expect(req2.body.thread_id).toBe null

        it "notifies of a permanent error on 500 errors", ->
          thrownError = new APIError(statusCode: 500, body: "err")
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            Promise.reject(thrownError)
          waitsForPromise => @task.performRemote().then (status) =>
            expect(status[0]).toBe Task.Status.Failed
            expect(status[1]).toBe thrownError
            expect(Actions.draftSendingFailed).toHaveBeenCalled()

        it "notifies us and users of a permanent error on 400 errors", ->
          thrownError = new APIError(statusCode: 400, body: "err")
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            Promise.reject(thrownError)
          waitsForPromise => @task.performRemote().then (status) =>
            expect(status[0]).toBe Task.Status.Failed
            expect(status[1]).toBe thrownError
            expect(Actions.draftSendingFailed).toHaveBeenCalled()

        it "retries on timeouts", ->
          thrownError = new APIError(statusCode: NylasAPI.TimeoutErrorCode, body: "err")
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            Promise.reject(thrownError)
          waitsForPromise => @task.performRemote().then (status) =>
            expect(status).toBe Task.Status.Retry

        describe "checking the promise chain halts on errors", ->
          beforeEach ->
            spyOn(@task,"_sendAndCreateMessage").andCallThrough()
            spyOn(@task,"_deleteRemoteDraft").andCallThrough()
            spyOn(@task,"_onSuccess").andCallThrough()
            spyOn(@task,"_onError").andCallThrough()

            @expectBlockedChain = =>
              expect(@task._sendAndCreateMessage).toHaveBeenCalled()
              expect(@task._deleteRemoteDraft).not.toHaveBeenCalled()
              expect(@task._onSuccess).not.toHaveBeenCalled()
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
              expect(@task._sendAndCreateMessage).toHaveBeenCalled()
              expect(@task._deleteRemoteDraft).toHaveBeenCalled()
              expect(@task._onSuccess).toHaveBeenCalled()
              expect(@task._onError).not.toHaveBeenCalled()

    describe "with a new draft", ->
      beforeEach ->
        @draft = new Message
          version: 1
          clientId: 'client-id'
          accountId: TEST_ACCOUNT_ID
          from: [new Contact(email: TEST_ACCOUNT_EMAIL)]
          subject: 'New Draft'
          draft: true
          body: 'hello world'
          uploads: []
        @task = new SendDraftTask(@draft)
        @calledBody = "ERROR: The body wasn't included!"
        spyOn(DatabaseStore, "findBy").andCallFake =>
          include: (body) =>
            @calledBody = body
            Promise.resolve(@draft)

      sharedTests()

      it "can complete a full performRemote", -> waitsForPromise =>
        @task.performRemote().then (status) ->
          expect(status).toBe Task.Status.Success

      it "shouldn't attempt to delete a draft", -> waitsForPromise =>
        @task._deleteRemoteDraft().then =>
          expect(NylasAPI.makeRequest).not.toHaveBeenCalled()

      it "should locally convert the draft to a message on send", ->
        waitsForPromise => @task.performRemote().then =>
          expect(DBt.persistModel).toHaveBeenCalled()
          model = DBt.persistModel.calls[0].args[0]
          expect(model.clientId).toBe @draft.clientId
          expect(model.serverId).toBe @response.id
          expect(model.draft).toBe false

    describe "with an existing persisted draft", ->
      beforeEach ->
        @draft = new Message
          version: 1
          clientId: 'client-id'
          serverId: 'server-123'
          accountId: TEST_ACCOUNT_ID
          from: [new Contact(email: TEST_ACCOUNT_EMAIL)]
          subject: 'New Draft'
          draft: true
          body: 'hello world'
          to:
            name: 'Dummy'
            email: 'dummy@nylas.com'
          uploads: []
        @task = new SendDraftTask(@draft)
        @calledBody = "ERROR: The body wasn't included!"
        spyOn(DatabaseStore, "findBy").andCallFake =>
          then: -> throw new Error("You must include the body!")
          include: (body) =>
            @calledBody = body
            Promise.resolve(@draft)

      sharedTests()

      it "can complete a full performRemote", -> waitsForPromise =>
        @task.performLocal()
        @task.performRemote().then (status) ->
          expect(status).toBe Task.Status.Success

      it "should make a request to delete a draft", ->
        @task.performLocal()
        waitsForPromise => @task._deleteRemoteDraft().then =>
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          expect(NylasAPI.makeRequest.callCount).toBe 1
          req = NylasAPI.makeRequest.calls[0].args[0]
          expect(req.path).toBe "/drafts/#{@draft.serverId}"
          expect(req.accountId).toBe TEST_ACCOUNT_ID
          expect(req.method).toBe "DELETE"
          expect(req.returnsModel).toBe false

      it "should continue if the request fails", ->
        jasmine.unspy(NylasAPI, "makeRequest")
        spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
          Promise.reject(new APIError(body: "Boo", statusCode: 500))

        @task.performLocal()
        waitsForPromise => @task._deleteRemoteDraft().then =>
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          expect(NylasAPI.makeRequest.callCount).toBe 1
        .catch =>
          throw new Error("Shouldn't fail the promise")

      it "should locally convert the existing draft to a message on send", ->
        expect(@draft.clientId).toBe @draft.clientId
        expect(@draft.serverId).toBe "server-123"

        @task.performLocal()
        waitsForPromise => @task.performRemote().then =>
          expect(DBt.persistModel).toHaveBeenCalled()
          model = DBt.persistModel.calls[0].args[0]
          expect(model.clientId).toBe @draft.clientId
          expect(model.serverId).toBe @response.id
          expect(model.draft).toBe false
