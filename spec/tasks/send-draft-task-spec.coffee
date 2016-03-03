_ = require 'underscore'
fs = require 'fs'
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
      draftA = new Message
        version: '1'
        clientId: 'localid-A'
        serverId: '1233123AEDF1'
        accountId: 'A12ADE'
        subject: 'New Draft'
        draft: true
        to:
          name: 'Dummy'
          email: 'dummy@nylas.com'

      saveA = new SyncbackDraftTask(draftA, [])
      sendA = new SendDraftTask(draftA, [])

      expect(sendA.isDependentTask(saveA)).toBe(false)

  describe "performLocal", ->
    it "rejects if we we don't pass a draft", ->
      badTask = new SendDraftTask()
      badTask.performLocal().then ->
        throw new Error("Shouldn't succeed")
      .catch (err) ->
        expect(err.message).toBe "SendDraftTask - must be provided a draft."

    it "rejects if we we don't pass uploads", ->
      message = new Message(from: [new Contact(email: TEST_ACCOUNT_EMAIL)])
      message.uploads = null
      badTask = new SendDraftTask(message)
      badTask.performLocal().then ->
        throw new Error("Shouldn't succeed")
      .catch (err) ->
        expect(err.message).toBe "SendDraftTask - must be provided an array of uploads."

    it "rejects if no from address is specified", ->
      badTask = new SendDraftTask(new Message(from: [], uploads: []))
      badTask.performLocal().then ->
        throw new Error("Shouldn't succeed")
      .catch (err) ->
        expect(err.message).toBe "SendDraftTask - you must populate `from` before sending."

    it "rejects if the from address does not map to any account", ->
      badTask = new SendDraftTask(new Message(from: [new Contact(email: 'not-configured@nylas.com')], uploads: null))
      badTask.performLocal().then ->
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
      spyOn(DBt, 'unpersistModel').andReturn Promise.resolve()
      spyOn(DBt, 'persistModel').andReturn Promise.resolve()
      spyOn(SoundRegistry, "playSound")
      spyOn(Actions, "postNotification")
      spyOn(Actions, "sendDraftSuccess")
      spyOn(Actions, "attachmentUploaded")
      spyOn(fs, 'createReadStream').andReturn "stub"

    # The tests below are invoked twice, once with a new @draft and one with a
    # persisted @draft.

    sharedTests = =>
      it "should return Task.Status.Success", ->
        waitsForPromise =>
          @task.performLocal()
          @task.performRemote().then (status) ->
            expect(status).toBe Task.Status.Success

      it "makes a send request with the correct data", ->
        waitsForPromise => @task._sendAndCreateMessage().then =>
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          expect(NylasAPI.makeRequest.callCount).toBe(1)
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.path).toBe("/send")
          expect(options.method).toBe('POST')
          expect(options.accountId).toBe TEST_ACCOUNT_ID
          expect(options.body).toEqual @draft.toJSON()

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

      describe "saving the sent message", ->
        it "should preserve the draft client id", ->
          waitsForPromise =>
            @task._sendAndCreateMessage().then =>
              expect(DBt.persistModel).toHaveBeenCalled()
              model = DBt.persistModel.mostRecentCall.args[0]
              expect(model.clientId).toEqual(@draft.clientId)
              expect(model.serverId).toEqual(@response.id)
              expect(model.draft).toEqual(false)

        it "should preserve metadata, but not version numbers", ->
          waitsForPromise =>
            @task._sendAndCreateMessage().then =>
              expect(DBt.persistModel).toHaveBeenCalled()
              model = DBt.persistModel.mostRecentCall.args[0]

              expect(model.pluginMetadata.length).toEqual(@draft.pluginMetadata.length)

              for {pluginId, value, version} in @draft.pluginMetadata
                updated = model.metadataObjectForPluginId(pluginId)
                expect(updated.value).toEqual(value)
                expect(updated.version).toEqual(0)

      it "should notify the draft was sent", ->
        waitsForPromise =>
          @task.performRemote().then =>
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

        @draft.applyPluginMetadata('pluginIdA', {tracked: true})
        @draft.applyPluginMetadata('pluginIdB', {a: true, b: 2})
        @draft.metadataObjectForPluginId('pluginIdA').version = 2

        @task = new SendDraftTask(@draft)
        @calledBody = "ERROR: The body wasn't included!"
        spyOn(DatabaseStore, "findBy").andCallFake =>
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

      describe "deleteRemoteDraft", ->
        it "should not make an API request", ->
          waitsForPromise =>
            @task._deleteRemoteDraft(@draft).then =>
              expect(NylasAPI.makeRequest).not.toHaveBeenCalled()


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

        @task = new SendDraftTask(@draft)
        @calledBody = "ERROR: The body wasn't included!"
        spyOn(DatabaseStore, "findBy").andCallFake =>
          Promise.resolve(@draft)

      sharedTests()

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

      describe "deleteRemoteDraft", ->
        it "should make an API request to delete the draft", ->
          @task.performLocal()
          waitsForPromise =>
            @task._deleteRemoteDraft(@draft).then =>
              expect(NylasAPI.makeRequest).toHaveBeenCalled()
              expect(NylasAPI.makeRequest.callCount).toBe 1
              req = NylasAPI.makeRequest.calls[0].args[0]
              expect(req.path).toBe "/drafts/#{@draft.serverId}"
              expect(req.accountId).toBe TEST_ACCOUNT_ID
              expect(req.method).toBe "DELETE"
              expect(req.returnsModel).toBe false

        it "should increment the change tracker, preventing any further deltas about the draft", ->
          @task.performLocal()
          waitsForPromise =>
            @task._deleteRemoteDraft(@draft).then =>
              expect(NylasAPI.incrementRemoteChangeLock).toHaveBeenCalledWith(Message, @draft.serverId)

        it "should continue if the request fails", ->
          jasmine.unspy(NylasAPI, "makeRequest")
          spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
            Promise.reject(new APIError(body: "Boo", statusCode: 500))

          @task.performLocal()
          waitsForPromise =>
            @task._deleteRemoteDraft(@draft)
            .then =>
              expect(NylasAPI.makeRequest).toHaveBeenCalled()
              expect(NylasAPI.makeRequest.callCount).toBe 1
            .catch =>
              throw new Error("Shouldn't fail the promise")

    describe "with uploads", ->
      beforeEach ->
        @uploads = [
          {targetPath: '/test-file-1.png', size: 100},
          {targetPath: '/test-file-2.png', size: 100}
        ]
        @draft = new Message
          version: 1
          clientId: 'client-id'
          accountId: TEST_ACCOUNT_ID
          from: [new Contact(email: TEST_ACCOUNT_EMAIL)]
          subject: 'New Draft'
          draft: true
          body: 'hello world'
          uploads: [].concat(@uploads)

        @task = new SendDraftTask(@draft)
        jasmine.unspy(NylasAPI, 'makeRequest')

        @resolves = []
        @resolveAll = =>
          resolve() for resolve in @resolves
          @resolves = []
          advanceClock()

        spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
          response = @response

          if options.path is '/files'
            response = JSON.stringify([{
              id: '1234'
              account_id: TEST_ACCOUNT_ID
              filename: options.formData.file.options.filename
            }])

          new Promise (resolve, reject) =>
            @resolves.push =>
              options.success?(response)
              resolve(response)

        spyOn(DatabaseStore, 'findBy').andCallFake =>
          Promise.resolve(@draft)

      it "should begin file uploads and not hit /send until they complete", ->
        @task.performRemote()
        advanceClock()

        # uploads should be queued, but not the send
        expect(NylasAPI.makeRequest.callCount).toEqual(2)
        expect(NylasAPI.makeRequest.calls[0].args[0].formData).toEqual({ file : { value : 'stub', options : { filename : 'test-file-1.png' } } })
        expect(NylasAPI.makeRequest.calls[1].args[0].formData).toEqual({ file : { value : 'stub', options : { filename : 'test-file-2.png' } } })

        # finish all uploads
        @resolveAll()

        # send should now be queued
        expect(NylasAPI.makeRequest.callCount).toEqual(3)
        expect(NylasAPI.makeRequest.calls[2].args[0].path).toEqual('/send')

      it "should convert the uploads to files", ->
        @task.performRemote()
        advanceClock()
        expect(@task.draft.files.length).toEqual(0)
        expect(@task.draft.uploads.length).toEqual(2)
        @resolves[0]()
        advanceClock()
        expect(@task.draft.files.length).toEqual(1)
        expect(@task.draft.uploads.length).toEqual(1)

        {filename, accountId, id} = @task.draft.files[0]
        expect({filename, accountId, id}).toEqual({
          filename: 'test-file-1.png',
          accountId: TEST_ACCOUNT_ID,
          id: '1234'
        })

      describe "cancel, during attachment upload", ->
        it "should make the task resolve early, before making the /send call", ->
          exitStatus = null
          @task.performRemote().then (status) => exitStatus = status
          advanceClock()
          @task.cancel()
          NylasAPI.makeRequest.reset()
          @resolveAll()
          advanceClock()
          expect(NylasAPI.makeRequest).not.toHaveBeenCalled()
          expect(exitStatus).toEqual(Task.Status.Continue)

      describe "after the message sends", ->
        it "should notify the attachments were uploaded (so they can be deleted)", ->
          @task.performRemote()
          advanceClock()
          @resolveAll() # uploads
          @resolveAll() # send
          expect(Actions.attachmentUploaded).toHaveBeenCalled()
          expect(Actions.attachmentUploaded.callCount).toEqual(@uploads.length)
          for upload, idx in @uploads
            expect(Actions.attachmentUploaded.calls[idx].args[0]).toBe(upload)
