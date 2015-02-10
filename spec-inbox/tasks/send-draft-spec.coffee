Actions = require '../../src/flux/actions'
SaveDraftTask = require '../../src/flux/tasks/save-draft'
SendDraftTask = require '../../src/flux/tasks/send-draft'
DatabaseStore = require '../../src/flux/stores/database-store'
{generateTempId} = require '../../src/flux/models/utils'
Message = require '../../src/flux/models/message'
_ = require 'underscore-plus'

describe "SendDraftTask", ->
  describe "shouldWaitForTask", ->
    it "should return any SaveDraftTasks for the same draft", ->
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

      @saveA = new SaveDraftTask('localid-A')
      @saveB = new SaveDraftTask('localid-B')
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

    it "should send the draft ID and version", ->
      waitsForPromise =>
        @task.performRemote().then =>
          expect(atom.inbox.makeRequest.calls.length).toBe(1)
          options = atom.inbox.makeRequest.mostRecentCall.args[0]
          expect(options.body.version).toBe(@draft.version)
          expect(options.body.draft_id).toBe(@draft.id)

    it "should pass returnsModel:true so that the draft is saved to the data store when returned", ->
      waitsForPromise =>
        @task.performRemote().then ->
          expect(atom.inbox.makeRequest.calls.length).toBe(1)
          options = atom.inbox.makeRequest.mostRecentCall.args[0]
          expect(options.returnsModel).toBe(true)
