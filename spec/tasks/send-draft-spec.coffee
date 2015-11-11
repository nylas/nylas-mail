NylasAPI = require '../../src/flux/nylas-api'
Actions = require '../../src/flux/actions'
SyncbackDraftTask = require '../../src/flux/tasks/syncback-draft'
FileUploadTask = require '../../src/flux/tasks/file-upload-task'
SendDraftTask = require '../../src/flux/tasks/send-draft'
DatabaseStore = require '../../src/flux/stores/database-store'
{APIError} = require '../../src/flux/errors'
Message = require '../../src/flux/models/message'
TaskQueue = require '../../src/flux/stores/task-queue'
SoundRegistry = require '../../src/sound-registry'
_ = require 'underscore'

describe "SendDraftTask", ->
  describe "isDependentTask", ->
    it "should return true if there are SyncbackDraftTasks for the same draft", ->
      @draftA = new Message
        version: '1'
        id: '1233123AEDF1'
        accountId: 'A12ADE'
        subject: 'New Draft'
        draft: true
        to:
          name: 'Dummy'
          email: 'dummy@nylas.com'

      @draftB = new Message
        version: '1'
        id: '1233OTHERDRAFT'
        accountId: 'A12ADE'
        subject: 'New Draft'
        draft: true
        to:
          name: 'Dummy'
          email: 'dummy@nylas.com'

      @saveA = new SyncbackDraftTask('localid-A')
      @saveB = new SyncbackDraftTask('localid-B')
      @sendA = new SendDraftTask('localid-A')

      expect(@sendA.isDependentTask(@saveA)).toBe(true)

  describe "performLocal", ->
    it "should throw an exception if the first parameter is not a clientId", ->
      badTasks = [new SendDraftTask()]
      goodTasks = [new SendDraftTask('localid-a')]
      caught = []
      succeeded = []

      runs ->
        [].concat(badTasks, goodTasks).forEach (task) ->
          task.performLocal()
          .then -> succeeded.push(task)
          .catch (err) -> caught.push(task)

      waitsFor ->
        succeeded.length + caught.length == badTasks.length + goodTasks.length

      runs ->
        expect(caught).toEqual(badTasks)
        expect(succeeded).toEqual(goodTasks)

  describe "performRemote", ->
    beforeEach ->
      @draftClientId = "local-123"
      @serverMessageId = '1233123AEDF1'
      @draft = new Message
        version: 1
        clientId: @draftClientId
        accountId: 'A12ADE'
        subject: 'New Draft'
        draft: true
        body: 'hello world'
        to:
          name: 'Dummy'
          email: 'dummy@nylas.com'

      response =
        version: 2
        id: @serverMessageId
        account_id: 'A12ADE'
        subject: 'New Draft'
        body: 'hello world'
        to:
          name: 'Dummy'
          email: 'dummy@nylas.com'

      @task = new SendDraftTask(@draftClientId)


      spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
        options.success?(response)
        Promise.resolve(response)
      spyOn(DatabaseStore, 'run').andCallFake (klass, id) =>
        Promise.resolve(@draft)
      spyOn(DatabaseStore, 'unpersistModel').andCallFake (draft) ->
        Promise.resolve()
      spyOn(DatabaseStore, 'persistModel').andCallFake (draft) ->
        Promise.resolve()
      spyOn(SoundRegistry, "playSound")
      spyOn(Actions, "postNotification")
      spyOn(Actions, "sendDraftSuccess")

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

    it "should start an API request to /send", ->
      waitsForPromise =>
        @task.performRemote().then =>
          expect(NylasAPI.makeRequest.calls.length).toBe(1)
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.path).toBe("/send")
          expect(options.accountId).toBe(@draft.accountId)
          expect(options.method).toBe('POST')

    it "should locally convert the draft to a message on send", ->
      expect(@draft.clientId).toBe @draftClientId
      expect(@draft.serverId).toBeUndefined()
      waitsForPromise =>
        @task.performRemote().then =>
          expect(DatabaseStore.persistModel).toHaveBeenCalled()
          model = DatabaseStore.persistModel.calls[0].args[0]
          expect(model.clientId).toBe @draftClientId
          expect(model.serverId).toBe @serverMessageId
          expect(model.draft).toBe false

    describe "when the draft has been saved", ->
      it "should send the draft ID and version", ->
        waitsForPromise =>
          @task.performRemote().then =>
            expect(NylasAPI.makeRequest.calls.length).toBe(1)
            options = NylasAPI.makeRequest.mostRecentCall.args[0]
            expect(options.body.version/1).toBe(1)
            expect(options.body.draft_id).toBe(@draft.serverId)

    describe "when the draft has not been saved", ->
      beforeEach ->
        @draft = new Message
          serverId: null
          clientId: @draftClientId
          accountId: 'A12ADE'
          subject: 'New Draft'
          draft: true
          body: 'hello world'
          to:
            name: 'Dummy'
            email: 'dummy@nylas.com'
        @task = new SendDraftTask(@draftClientId)

      it "should send the draft JSON", ->
        waitsForPromise =>
          expectedJSON = @draft.toJSON()
          @task.performRemote().then =>
            expect(NylasAPI.makeRequest.calls.length).toBe(1)
            options = NylasAPI.makeRequest.mostRecentCall.args[0]
            expect(options.body).toEqual(expectedJSON)

      it "should always send the draft body in the request body (joined attribute check)", ->
        waitsForPromise =>
          @task.performRemote().then =>
            expect(NylasAPI.makeRequest.calls.length).toBe(1)
            options = NylasAPI.makeRequest.mostRecentCall.args[0]
            expect(options.body.body).toBe('hello world')

    it "should pass returnsModel:false", ->
      waitsForPromise =>
        @task.performRemote().then ->
          expect(NylasAPI.makeRequest.calls.length).toBe(1)
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.returnsModel).toBe(false)

    it "should write the saved message to the database with the same client ID", ->
      waitsForPromise =>
        @task.performRemote().then =>
          expect(DatabaseStore.persistModel).toHaveBeenCalled()
          expect(DatabaseStore.persistModel.mostRecentCall.args[0].clientId).toEqual(@draftClientId)
          expect(DatabaseStore.persistModel.mostRecentCall.args[0].serverId).toEqual('1233123AEDF1')
          expect(DatabaseStore.persistModel.mostRecentCall.args[0].draft).toEqual(false)

  describe "failing performRemote", ->
    beforeEach ->
      @draft = new Message
        version: '1'
        clientId: @draftClientId
        accountId: 'A12ADE'
        threadId: 'threadId'
        replyToMessageId: 'replyToMessageId'
        subject: 'New Draft'
        body: 'body'
        draft: true
        to:
          name: 'Dummy'
          email: 'dummy@nylas.com'
      @task = new SendDraftTask("local-1234")
      spyOn(Actions, "dequeueTask")
      spyOn(DatabaseStore, 'unpersistModel').andCallFake (draft) ->
        Promise.resolve()
      spyOn(DatabaseStore, 'persistModel').andCallFake (draft) ->
        Promise.resolve()

    describe "when the server responds with `Invalid message public ID`", ->
      it "should resend the draft without the reply_to_message_id key set", ->
        spyOn(DatabaseStore, 'run').andCallFake =>
          Promise.resolve(@draft)
        spyOn(NylasAPI, 'makeRequest').andCallFake ({body, success, error}) =>
          if body.reply_to_message_id
            err = new APIError(body: "Invalid message public id", statusCode: 400)
            error?(err)
            return Promise.reject(err)
          else
            success?(body)
            return Promise.resolve(body)

        waitsForPromise =>
          @task.performRemote().then =>
            expect(NylasAPI.makeRequest.calls.length).toBe(2)
            expect(NylasAPI.makeRequest.calls[1].args[0].body.thread_id).toBe('threadId')
            expect(NylasAPI.makeRequest.calls[1].args[0].body.reply_to_message_id).toBe(null)

    describe "when the server responds with `Invalid thread ID`", ->
      it "should resend the draft without the thread_id or reply_to_message_id keys set", ->
        spyOn(DatabaseStore, 'run').andCallFake => Promise.resolve(@draft)
        spyOn(NylasAPI, 'makeRequest').andCallFake ({body, success, error}) =>
          new Promise (resolve, reject) =>
            if body.thread_id
              err = new APIError(body: "Invalid thread public id", statusCode: 400)
              error?(err)
              reject(err)
            else
              success?(body)
              resolve(body)

        waitsForPromise =>
          @task.performRemote().then =>
            expect(NylasAPI.makeRequest.calls.length).toBe(2)
            expect(NylasAPI.makeRequest.calls[1].args[0].body.thread_id).toBe(null)
            expect(NylasAPI.makeRequest.calls[1].args[0].body.reply_to_message_id).toBe(null)
          .catch (err) =>
            console.log(err.trace)

    it "throws an error if the draft can't be found", ->
      spyOn(DatabaseStore, 'run').andCallFake (klass, clientId) ->
        Promise.resolve()
      waitsForPromise =>
        @task.performRemote().catch (error) ->
          expect(error.message).toBeDefined()

    it "throws an error if the draft isn't saved", ->
      spyOn(DatabaseStore, 'run').andCallFake (klass, clientId) ->
        Promise.resolve(serverId: null)
      waitsForPromise =>
        @task.performRemote().catch (error) ->
          expect(error.message).toBeDefined()

    it "throws an error if the DB store has issues", ->
      spyOn(DatabaseStore, 'run').andCallFake (klass, clientId) ->
        Promise.reject("DB error")
      waitsForPromise =>
        @task.performRemote().catch (error) ->
          expect(error).toBe "DB error"

  describe "failing dependent task", ->
    it "notifies the user that the required draft save failed", ->
      task = new SendDraftTask("local-1234")
      syncback = new SyncbackDraftTask('local-1234')
      spyOn(task, "_notifyUserOfError")
      task.onDependentTaskError(syncback, new Error("Oh no"))
      expect(task._notifyUserOfError).toHaveBeenCalled()
      expect(task._notifyUserOfError.calls.length).toBe 1

    it "notifies the user that the required file upload failed", ->
      task = new SendDraftTask("local-1234")
      fileUploadTask = new FileUploadTask('/dev/null', 'local-1234')
      spyOn(task, "_notifyUserOfError")
      task.onDependentTaskError(fileUploadTask, new Error("Oh no"))
      expect(task._notifyUserOfError).toHaveBeenCalled()
      expect(task._notifyUserOfError.calls.length).toBe 1

