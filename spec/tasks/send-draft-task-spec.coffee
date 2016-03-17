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

  describe "assertDraftValidity", ->
    it "rejects if there are still uploads on the draft", ->
      badTask = new SendDraftTask('1')
      badTask.draft = new Message(from: [new Contact(email: TEST_ACCOUNT_EMAIL)], accountId: TEST_ACCOUNT_ID, clientId: '1', uploads: ['123'])
      badTask.assertDraftValidity().then ->
        throw new Error("Shouldn't succeed")
      .catch (err) ->
        expect(err.message).toBe "Files have been added since you started sending this draft. Double-check the draft and click 'Send' again.."

    it "rejects if no from address is specified", ->
      badTask = new SendDraftTask('1')
      badTask.draft = new Message(from: [], uploads: [], accountId: TEST_ACCOUNT_ID, clientId: '1')
      badTask.assertDraftValidity().then ->
        throw new Error("Shouldn't succeed")
      .catch (err) ->
        expect(err.message).toBe "SendDraftTask - you must populate `from` before sending."

    it "rejects if the from address does not map to any account", ->
      badTask = new SendDraftTask('1')
      badTask.draft = new Message(from: [new Contact(email: 'not-configured@nylas.com')], accountId: TEST_ACCOUNT_ID, clientId: '1')
      badTask.assertDraftValidity().then ->
        throw new Error("Shouldn't succeed")
      .catch (err) ->
        expect(err.message).toBe "SendDraftTask - you can only send drafts from a configured account."

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
        return Promise.resolve(@response)
      spyOn(NylasAPI, 'incrementRemoteChangeLock')
      spyOn(NylasAPI, 'decrementRemoteChangeLock')
      spyOn(NylasAPI, 'makeDraftDeletionRequest')
      spyOn(DBt, 'unpersistModel').andReturn Promise.resolve()
      spyOn(DBt, 'persistModel').andReturn Promise.resolve()
      spyOn(SoundRegistry, "playSound")
      spyOn(Actions, "postNotification")
      spyOn(Actions, "sendDraftSuccess")

    # The tests below are invoked twice, once with a new @draft and one with a
    # persisted @draft.

    sharedTests = =>
      it "should return Task.Status.Success", ->
        waitsForPromise =>
          @task.performLocal()
          @task.performRemote().then (status) ->
            expect(status).toBe Task.Status.Success

      it "makes a send request with the correct data", ->
        waitsForPromise => @task.performRemote().then =>
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          expect(NylasAPI.makeRequest.callCount).toBe(1)
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.path).toBe("/send")
          expect(options.method).toBe('POST')
          expect(options.accountId).toBe TEST_ACCOUNT_ID
          expect(options.body).toEqual @draft.toJSON()

      it "should pass returnsModel:false", ->
        waitsForPromise => @task.performRemote().then =>
          expect(NylasAPI.makeRequest.calls.length).toBe(1)
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.returnsModel).toBe(false)

      it "should always send the draft body in the request body (joined attribute check)", ->
        waitsForPromise => @task.performRemote().then =>
          expect(NylasAPI.makeRequest.calls.length).toBe(1)
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.body.body).toBe('hello world')

      describe "saving the sent message", ->
        it "should preserve the draft client id", ->
          waitsForPromise => @task.performRemote().then =>
            expect(DBt.persistModel).toHaveBeenCalled()
            model = DBt.persistModel.mostRecentCall.args[0]
            expect(model.clientId).toEqual(@draft.clientId)
            expect(model.serverId).toEqual(@response.id)
            expect(model.draft).toEqual(false)

        it "should preserve metadata, but not version numbers", ->
          waitsForPromise => @task.performRemote().then =>
            expect(DBt.persistModel).toHaveBeenCalled()
            model = DBt.persistModel.mostRecentCall.args[0]

            expect(model.pluginMetadata.length).toEqual(@draft.pluginMetadata.length)

            for {pluginId, value, version} in @draft.pluginMetadata
              updated = model.metadataObjectForPluginId(pluginId)
              expect(updated.value).toEqual(value)
              expect(updated.version).toEqual(0)

      it "should notify the draft was sent", ->
        waitsForPromise => @task.performRemote().then =>
          args = Actions.sendDraftSuccess.calls[0].args[0]
          expect(args.message instanceof Message).toBe(true)
          expect(args.messageClientId).toBe(@draft.clientId)

      it "should queue tasks to sync back the metadata on the new message", ->
        waitsForPromise =>
          spyOn(Actions, 'queueTask')
          @task.performRemote().then =>
            metadataTasks = Actions.queueTask.calls.map (call) -> call.args[0]
            expect(metadataTasks.length).toEqual(@draft.pluginMetadata.length)
            for pluginMetadatum, idx in @draft.pluginMetadata
              expect(metadataTasks[idx].clientId).toEqual(@draft.clientId)
              expect(metadataTasks[idx].modelClassName).toEqual('Message')
              expect(metadataTasks[idx].pluginId).toEqual(pluginMetadatum.pluginId)

      it "should play a sound", ->
        spyOn(NylasEnv.config, "get").andReturn true
        waitsForPromise => @task.performRemote().then =>
          expect(NylasEnv.config.get).toHaveBeenCalledWith("core.sending.sounds")
          expect(SoundRegistry.playSound).toHaveBeenCalledWith("send")

      it "shouldn't play a sound if the config is disabled", ->
        spyOn(NylasEnv.config, "get").andReturn false
        waitsForPromise => @task.performRemote().then =>
          expect(NylasEnv.config.get).toHaveBeenCalledWith("core.sending.sounds")
          expect(SoundRegistry.playSound).not.toHaveBeenCalled()

      describe "when there are errors", ->
        beforeEach ->
          spyOn(Actions, 'draftSendingFailed')
          jasmine.unspy(NylasAPI, "makeRequest")

        it "notifies of a permanent error of misc error types", ->
          ## DB error
          thrownError = null
          spyOn(NylasEnv, "reportError")
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
          waitsForPromise => @task.performRemote(@draft).then =>
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
          waitsForPromise => @task.performRemote(@draft).then =>
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
          spyOn(NylasEnv, "reportError")
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            Promise.reject(thrownError)
          waitsForPromise => @task.performRemote().then (status) =>
            expect(status[0]).toBe Task.Status.Failed
            expect(status[1]).toBe thrownError
            expect(Actions.draftSendingFailed).toHaveBeenCalled()

        it "notifies us and users of a permanent error on 400 errors", ->
          thrownError = new APIError(statusCode: 400, body: "err")
          spyOn(NylasEnv, "reportError")
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            Promise.reject(thrownError)
          waitsForPromise => @task.performRemote().then (status) =>
            expect(status[0]).toBe Task.Status.Failed
            expect(status[1]).toBe thrownError
            expect(Actions.draftSendingFailed).toHaveBeenCalled()

        it "presents helpful error messages for 402 errors (security blocked)", ->
          thrownError = new APIError(statusCode: 402, body: {
            "message": "Message content rejected for security reasons",
            "server_error": "552 : 5.7.0 This message was blocked because its content presents a potential\n5.7.0 security issue. Please visit\n5.7.0  https://support.google.com/mail/answer/6590 to review our message\n5.7.0 content and attachment content guidelines. fk9sm21147314pad.9 - gsmtp",
            "type": "api_error"
          })

          expectedMessage =
          """
            Sorry, this message could not be sent because it was rejected by your mail provider. (Message content rejected for security reasons)

            552 : 5.7.0 This message was blocked because its content presents a potential
            5.7.0 security issue. Please visit
            5.7.0  https://support.google.com/mail/answer/6590 to review our message
            5.7.0 content and attachment content guidelines. fk9sm21147314pad.9 - gsmtp
          """

          spyOn(NylasEnv, "reportError")
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            Promise.reject(thrownError)
          waitsForPromise => @task.performRemote().then (status) =>
            expect(status[0]).toBe Task.Status.Failed
            expect(status[1]).toBe thrownError
            expect(Actions.draftSendingFailed).toHaveBeenCalled()
            expect(Actions.draftSendingFailed.calls[0].args[0].errorMessage).toEqual(expectedMessage)

        it "presents helpful error messages for 402 errors (recipient failed)", ->
          thrownError = new APIError(statusCode: 402, body: {
            "message": "Sending to at least one recipient failed.",
            "server_error": "<<Don't know what this looks like >>",
            "type": "api_error"
          })

          expectedMessage = "This message could not be delivered to at least one recipient. (Note: other recipients may have received this message - you should check Sent Mail before re-sending this message.)"

          spyOn(NylasEnv, "reportError")
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            Promise.reject(thrownError)
          waitsForPromise => @task.performRemote().then (status) =>
            expect(status[0]).toBe Task.Status.Failed
            expect(status[1]).toBe thrownError
            expect(Actions.draftSendingFailed).toHaveBeenCalled()
            expect(Actions.draftSendingFailed.calls[0].args[0].errorMessage).toEqual(expectedMessage)


        it "retries on timeouts", ->
          thrownError = new APIError(statusCode: NylasAPI.TimeoutErrorCode, body: "err")
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            Promise.reject(thrownError)
          waitsForPromise => @task.performRemote().then (status) =>
            expect(status).toBe Task.Status.Retry

        describe "checking the promise chain halts on errors", ->
          beforeEach ->
            spyOn(NylasEnv, 'reportError')
            spyOn(@task, "sendMessage").andCallThrough()
            spyOn(@task, "onSuccess").andCallThrough()
            spyOn(@task, "onError").andCallThrough()

            @expectBlockedChain = =>
              expect(@task.sendMessage).toHaveBeenCalled()
              expect(@task.onSuccess).not.toHaveBeenCalled()
              expect(@task.onError).toHaveBeenCalled()

          it "halts on 500s", ->
            thrownError = new APIError(statusCode: 500, body: "err")
            spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
              Promise.reject(thrownError)
            waitsForPromise =>
              @task.performRemote().then (status) =>
                @expectBlockedChain()

          it "halts on 400s", ->
            thrownError = new APIError(statusCode: 400, body: "err")
            spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
              Promise.reject(thrownError)
            waitsForPromise =>
              @task.performRemote().then (status) =>
                @expectBlockedChain()

          it "halts and retries on not permanent error codes", ->
            thrownError = new APIError(statusCode: 409, body: "err")
            spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
              Promise.reject(thrownError)
            waitsForPromise =>
              @task.performRemote().then (status) =>
                @expectBlockedChain()

          it "halts on other errors", ->
            thrownError = new Error("oh no")
            spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
              Promise.reject(thrownError)
            waitsForPromise =>
              @task.performRemote().then (status) =>
                @expectBlockedChain()

          it "doesn't halt on success", ->
            # Don't spy reportError to make sure to fail the test on unexpected
            # errors
            jasmine.unspy(NylasEnv, 'reportError')
            spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
              options.success?(@response)
              Promise.resolve(@response)
            waitsForPromise =>
              @task.performRemote().then (status) =>
                expect(status).toBe Task.Status.Success
                expect(@task.sendMessage).toHaveBeenCalled()
                expect(@task.onSuccess).toHaveBeenCalled()
                expect(@task.onError).not.toHaveBeenCalled()

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

        @draft.applyPluginMetadata('pluginIdA', {tracked: true})
        @draft.applyPluginMetadata('pluginIdB', {a: true, b: 2})
        @draft.metadataObjectForPluginId('pluginIdA').version = 2

        @task = new SendDraftTask('client-id')
        @calledBody = "ERROR: The body wasn't included!"
        spyOn(DatabaseStore, "run").andCallFake =>
          Promise.resolve(@draft)

      sharedTests()

      it "should locally convert the draft to a message on send", ->
        waitsForPromise =>
          @task.performRemote().then =>
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

        @draft.applyPluginMetadata('pluginIdA', {tracked: true})
        @draft.applyPluginMetadata('pluginIdB', {a: true, b: 2})
        @draft.metadataObjectForPluginId('pluginIdA').version = 2

        @task = new SendDraftTask('client-id')
        @calledBody = "ERROR: The body wasn't included!"
        spyOn(DatabaseStore, "run").andCallFake =>
          Promise.resolve(@draft)

      sharedTests()

      it "should call makeDraftDeletionRequest to delete the draft after sending", ->
        @task.performLocal()
        waitsForPromise => @task.performRemote().then =>
          expect(NylasAPI.makeDraftDeletionRequest).toHaveBeenCalled()

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
