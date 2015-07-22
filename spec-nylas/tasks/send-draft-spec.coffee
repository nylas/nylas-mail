NylasAPI = require '../../src/flux/nylas-api'
Actions = require '../../src/flux/actions'
SyncbackDraftTask = require '../../src/flux/tasks/syncback-draft'
SendDraftTask = require '../../src/flux/tasks/send-draft'
DatabaseStore = require '../../src/flux/stores/database-store'
{generateTempId} = require '../../src/flux/models/utils'
{APIError} = require '../../src/flux/errors'
Message = require '../../src/flux/models/message'
TaskQueue = require '../../src/flux/stores/task-queue'
_ = require 'underscore'

describe "SendDraftTask", ->
  describe "shouldWaitForTask", ->
    it "should return true if there are SyncbackDraftTasks for the same draft", ->
      @draftA = new Message
        version: '1'
        id: '1233123AEDF1'
        namespaceId: 'A12ADE'
        subject: 'New Draft'
        draft: true
        to:
          name: 'Dummy'
          email: 'dummy@nylas.com'

      @draftB = new Message
        version: '1'
        id: '1233OTHERDRAFT'
        namespaceId: 'A12ADE'
        subject: 'New Draft'
        draft: true
        to:
          name: 'Dummy'
          email: 'dummy@nylas.com'

      @saveA = new SyncbackDraftTask('localid-A')
      @saveB = new SyncbackDraftTask('localid-B')
      @sendA = new SendDraftTask('localid-A')

      expect(@sendA.shouldWaitForTask(@saveA)).toBe(true)

  describe "performLocal", ->
    it "should throw an exception if the first parameter is not a localId", ->
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
      @draft = new Message
        version: '1'
        id: '1233123AEDF1'
        namespaceId: 'A12ADE'
        subject: 'New Draft'
        draft: true
        body: 'hello world'
        to:
          name: 'Dummy'
          email: 'dummy@nylas.com'
      @draftLocalId = "local-123"
      @task = new SendDraftTask(@draftLocalId)
      spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
        options.success?(@draft.toJSON())
        Promise.resolve(@draft.toJSON())
      spyOn(DatabaseStore, 'findByLocalId').andCallFake (klass, localId) =>
        Promise.resolve(@draft)
      spyOn(DatabaseStore, 'unpersistModel').andCallFake (draft) ->
        Promise.resolve()
      spyOn(atom, "playSound")
      spyOn(Actions, "postNotification")
      spyOn(Actions, "sendDraftSuccess")

    it "should unpersist when successfully sent", ->
      waitsForPromise => @task.performRemote().then =>
        expect(DatabaseStore.unpersistModel).toHaveBeenCalledWith(@draft)

    it "should notify the draft was sent", ->
      waitsForPromise => @task.performRemote().then =>
        args = Actions.sendDraftSuccess.calls[0].args[0]
        expect(args.draftLocalId).toBe @draftLocalId

    it "get an object back on success", ->
      waitsForPromise => @task.performRemote().then =>
        args = Actions.sendDraftSuccess.calls[0].args[0]
        expect(args.newMessage.id).toBe @draft.id

    it "should play a sound", ->
      waitsForPromise => @task.performRemote().then ->
        expect(atom.playSound).toHaveBeenCalledWith("mail_sent.ogg")

    it "should start an API request to /send", ->
      waitsForPromise =>
        @task.performRemote().then =>
          expect(NylasAPI.makeRequest.calls.length).toBe(1)
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.path).toBe("/n/#{@draft.namespaceId}/send")
          expect(options.method).toBe('POST')

    describe "when the draft has been saved", ->
      it "should send the draft ID and version", ->
        waitsForPromise =>
          @task.performRemote().then =>
            expect(NylasAPI.makeRequest.calls.length).toBe(1)
            options = NylasAPI.makeRequest.mostRecentCall.args[0]
            expect(options.body.version).toBe(@draft.version)
            expect(options.body.draft_id).toBe(@draft.id)

    describe "when the draft has not been saved", ->
      beforeEach ->
        @draft = new Message
          id: generateTempId()
          namespaceId: 'A12ADE'
          subject: 'New Draft'
          draft: true
          body: 'hello world'
          to:
            name: 'Dummy'
            email: 'dummy@nylas.com'
        @task = new SendDraftTask(@draftLocalId)

      it "should send the draft JSON", ->
        waitsForPromise =>
          @task.performRemote().then =>
            expect(NylasAPI.makeRequest.calls.length).toBe(1)
            options = NylasAPI.makeRequest.mostRecentCall.args[0]
            expect(options.body).toEqual(@draft.toJSON())

      it "should always send the draft body in the request body (joined attribute check)", ->
        waitsForPromise =>
          @task.performRemote().then =>
            expect(NylasAPI.makeRequest.calls.length).toBe(1)
            options = NylasAPI.makeRequest.mostRecentCall.args[0]
            expect(options.body.body).toBe('hello world')

    it "should pass returnsModel:true so that the draft is saved to the data store when returned", ->
      waitsForPromise =>
        @task.performRemote().then ->
          expect(NylasAPI.makeRequest.calls.length).toBe(1)
          options = NylasAPI.makeRequest.mostRecentCall.args[0]
          expect(options.returnsModel).toBe(true)

  describe "failing performRemote", ->
    beforeEach ->
      @draft = new Message
        version: '1'
        id: '1233123AEDF1'
        namespaceId: 'A12ADE'
        threadId: 'threadId'
        replyToMessageId: 'replyToMessageId'
        subject: 'New Draft'
        body: 'body'
        draft: true
        to:
          name: 'Dummy'
          email: 'dummy@nylas.com'
      @task = new SendDraftTask(@draft.id)
      spyOn(Actions, "dequeueTask")
      spyOn(DatabaseStore, 'unpersistModel').andCallFake (draft) ->
        Promise.resolve()

    describe "when the server responds with `Invalid message public ID`", ->
      it "should resend the draft without the reply_to_message_id key set", ->
        @draft.id = generateTempId()
        spyOn(DatabaseStore, 'findByLocalId').andCallFake => Promise.resolve(@draft)
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
        @draft.id = generateTempId()
        spyOn(DatabaseStore, 'findByLocalId').andCallFake => Promise.resolve(@draft)
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
      spyOn(DatabaseStore, 'findByLocalId').andCallFake (klass, localId) ->
        Promise.resolve()
      waitsForPromise =>
        @task.performRemote().catch (error) ->
          expect(error.message).toBeDefined()

    it "throws an error if the draft isn't saved", ->
      spyOn(DatabaseStore, 'findByLocalId').andCallFake (klass, localId) ->
        Promise.resolve(isSaved: false)
      waitsForPromise =>
        @task.performRemote().catch (error) ->
          expect(error.message).toBeDefined()

    it "throws an error if the DB store has issues", ->
      spyOn(DatabaseStore, 'findByLocalId').andCallFake (klass, localId) ->
        Promise.reject("DB error")
      waitsForPromise =>
        @task.performRemote().catch (error) ->
          expect(error).toBe "DB error"
