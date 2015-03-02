Actions = require '../../src/flux/actions'
SyncbackDraftTask = require '../../src/flux/tasks/syncback-draft'
SendDraftTask = require '../../src/flux/tasks/send-draft'
DatabaseStore = require '../../src/flux/stores/database-store'
{generateTempId} = require '../../src/flux/models/utils'
Message = require '../../src/flux/models/message'
TaskQueue = require '../../src/flux/stores/task-queue'
_ = require 'underscore-plus'

describe "SendDraftTask", ->
  describe "shouldWaitForTask", ->
    it "should return any SyncbackDraftTasks for the same draft", ->
      @draftA = new Message
        version: '1'
        id: '1233123AEDF1'
        namespaceId: 'A12ADE'
        subject: 'New Draft'
        draft: true
        to:
          name: 'Dummy'
          email: 'dummy@inboxapp.com'

      @draftB = new Message
        version: '1'
        id: '1233OTHERDRAFT'
        namespaceId: 'A12ADE'
        subject: 'New Draft'
        draft: true
        to:
          name: 'Dummy'
          email: 'dummy@inboxapp.com'

      @saveA = new SyncbackDraftTask('localid-A')
      @saveB = new SyncbackDraftTask('localid-B')
      @sendA = new SendDraftTask('localid-A')

      expect(@sendA.shouldWaitForTask(@saveA)).toBe(true)

  describe "When on the TaskQueue", ->
    beforeEach ->
      TaskQueue._queue = []
      TaskQueue._completed = []
      @saveTask = new SyncbackDraftTask('localid-A')
      @saveTaskB = new SyncbackDraftTask('localid-B')
      @sendTask = new SendDraftTask('localid-A')
      @tasks = [@saveTask, @saveTaskB, @sendTask]

    describe "when tasks succeed", ->
      beforeEach ->
        for task in @tasks
          spyOn(task, "performLocal").andCallFake -> Promise.resolve()
          spyOn(task, "performRemote").andCallFake -> Promise.resolve()
        runs ->
          TaskQueue.enqueue(@saveTask, silent: true)
          TaskQueue.enqueue(@saveTaskB, silent: true)
          TaskQueue.enqueue(@sendTask)
        waitsFor ->
          @sendTask.queueState.performedRemote isnt false

      it "processes all of the items", ->
        runs ->
          expect(TaskQueue._queue.length).toBe 0
          expect(TaskQueue._completed.length).toBe 3

      it "all of the tasks", ->
        runs ->
          expect(@saveTask.performRemote).toHaveBeenCalled()
          expect(@saveTaskB.performRemote).toHaveBeenCalled()
          expect(@sendTask.performRemote).toHaveBeenCalled()

      it "finishes the save before sending", ->
        runs ->
          save = @saveTask.queueState.performedRemote
          send = @sendTask.queueState.performedRemote
          expect(save).toBeGreaterThan 0
          expect(send).toBeGreaterThan 0
          expect(save <= send).toBe true


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
        to:
          name: 'Dummy'
          email: 'dummy@inboxapp.com'
      @task = new SendDraftTask(@draft)
      spyOn(atom.inbox, 'makeRequest').andCallFake (options) ->
        options.success() if options.success
      spyOn(DatabaseStore, 'findByLocalId').andCallFake (klass, localId) =>
        Promise.resolve(@draft)
      spyOn(DatabaseStore, 'unpersistModel').andCallFake (draft) =>
        Promise.resolve()

    it "should start an API request to /send", ->
      waitsForPromise =>
        @task.performRemote().then =>
          expect(atom.inbox.makeRequest.calls.length).toBe(1)
          options = atom.inbox.makeRequest.mostRecentCall.args[0]
          expect(options.path).toBe("/n/#{@draft.namespaceId}/send")
          expect(options.method).toBe('POST')

    describe "when the draft has been saved", ->
      it "should send the draft ID and version", ->
        waitsForPromise =>
          @task.performRemote().then =>
            expect(atom.inbox.makeRequest.calls.length).toBe(1)
            options = atom.inbox.makeRequest.mostRecentCall.args[0]
            expect(options.body.version).toBe(@draft.version)
            expect(options.body.draft_id).toBe(@draft.id)

    describe "when the draft has not been saved", ->
      beforeEach ->
        @draft = new Message
          id: generateTempId()
          namespaceId: 'A12ADE'
          subject: 'New Draft'
          draft: true
          to:
            name: 'Dummy'
            email: 'dummy@inboxapp.com'
        @task = new SendDraftTask(@draft)

      it "should send the draft JSON", ->
        waitsForPromise =>
          @task.performRemote().then =>
            expect(atom.inbox.makeRequest.calls.length).toBe(1)
            options = atom.inbox.makeRequest.mostRecentCall.args[0]
            expect(options.body).toEqual(@draft.toJSON())

    it "should pass returnsModel:true so that the draft is saved to the data store when returned", ->
      waitsForPromise =>
        @task.performRemote().then ->
          expect(atom.inbox.makeRequest.calls.length).toBe(1)
          options = atom.inbox.makeRequest.mostRecentCall.args[0]
          expect(options.returnsModel).toBe(true)

  describe "failing performRemote", ->
    beforeEach ->
      @draft = new Message
        version: '1'
        id: '1233123AEDF1'
        namespaceId: 'A12ADE'
        subject: 'New Draft'
        draft: true
        to:
          name: 'Dummy'
          email: 'dummy@inboxapp.com'
      @task = new SendDraftTask(@draft)

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
