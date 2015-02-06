_ = require 'underscore-plus'
{generateTempId, isTempId} = require '../../src/flux/models/utils'

Task = require '../../src/flux/tasks/task'
Actions = require '../../src/flux/actions'
Message = require '../../src/flux/models/message'
Contact = require '../../src/flux/models/contact'
{APIError} = require '../../src/flux/errors'
DatabaseStore = require '../../src/flux/stores/database-store'

SaveDraftTask = require '../../src/flux/tasks/save-draft'

inboxError =
  message: "No draft with public id bvn4aydxuyqlbmzowh4wraysg",
  type: "invalid_request_error"

testError = (opts) ->
  new APIError
    error:null
    response:{statusCode: 404}
    body:inboxError
    requestOptions: opts

testData =
  to: new Contact(name: "Ben Gotow", email: "ben@inboxapp.com")
  from: new Contact(name: "Evan Morikawa", email: "evan@inboxapp.com")
  date: new Date
  draft: true
  subject: "Test"
  namespaceId: "abc123"

localDraft = new Message _.extend {}, testData, {id: "local-id"}
remoteDraft = new Message _.extend {}, testData, {id: "remoteid1234"}

describe "SaveDraftTask", ->
  beforeEach ->
    spyOn(DatabaseStore, "findByLocalId").andCallFake (klass, localId) ->
      if localId is "localDraftId" then Promise.resolve(localDraft)
      else if localId is "remoteDraftId" then Promise.resolve(remoteDraft)
      else if localId is "missingDraftId" then Promise.resolve()

    spyOn(DatabaseStore, "persistModel").andCallFake ->
      Promise.resolve()

    spyOn(DatabaseStore, "swapModel").andCallFake ->
      Promise.resolve()

  describe "performLocal", ->
    it "rejects if it isn't constructed with a draftLocalId", ->
      task = new SaveDraftTask
      waitsForPromise =>
        task.performLocal().catch (error) ->
          expect(error.message).toBeDefined()

    it "does nothing if there are no new changes", ->
      task = new SaveDraftTask("localDraftId")
      waitsForPromise =>
        task.performLocal().then ->
          expect(DatabaseStore.persistModel).not.toHaveBeenCalled()

    it "persists to the Database if there are new changes", ->
      task = new SaveDraftTask("localDraftId", body: "test body")
      waitsForPromise =>
        task.performLocal().then ->
          expect(DatabaseStore.persistModel).toHaveBeenCalled()
          newBody = DatabaseStore.persistModel.calls[0].args[0].body
          expect(newBody).toBe "test body"

  describe "performRemote", ->
    beforeEach ->
      spyOn(atom.inbox, 'makeRequest').andCallFake (opts) ->
        opts.success(remoteDraft.toJSON())

    it "does nothing if localOnly is set to true", ->
      task = new SaveDraftTask("localDraftId", {}, localOnly: true)
      waitsForPromise =>
        task.performRemote().then ->
          expect(DatabaseStore.findByLocalId).not.toHaveBeenCalled()
          expect(atom.inbox.makeRequest).not.toHaveBeenCalled()

    it "does nothing if no draft can be found in the db", ->
      task = new SaveDraftTask("missingDraftId")
      waitsForPromise =>
        task.performRemote().then ->
          expect(atom.inbox.makeRequest).not.toHaveBeenCalled()

    it "should start an API request with the Message JSON", ->
      task = new SaveDraftTask("localDraftId")
      waitsForPromise =>
        task.performRemote().then ->
          expect(atom.inbox.makeRequest).toHaveBeenCalled()
          reqBody = atom.inbox.makeRequest.mostRecentCall.args[0].body
          expect(reqBody.subject).toEqual testData.subject

    it "should do a PUT when the draft has already been saved", ->
      task = new SaveDraftTask("remoteDraftId")
      waitsForPromise =>
        task.performRemote().then ->
          expect(atom.inbox.makeRequest).toHaveBeenCalled()
          options = atom.inbox.makeRequest.mostRecentCall.args[0]
          expect(options.path).toBe("/n/abc123/drafts/remoteid1234")
          expect(options.method).toBe('PUT')

    it "should do a POST when the draft is unsaved", ->
      task = new SaveDraftTask("localDraftId")
      waitsForPromise =>
        task.performRemote().then ->
          expect(atom.inbox.makeRequest).toHaveBeenCalled()
          options = atom.inbox.makeRequest.mostRecentCall.args[0]
          expect(options.path).toBe("/n/abc123/drafts")
          expect(options.method).toBe('POST')

    it "should pass returnsModel:false so that the draft can be manually removed/added to the database, accounting for its ID change", ->
      task = new SaveDraftTask("localDraftId")
      waitsForPromise =>
        task.performRemote().then ->
          expect(atom.inbox.makeRequest).toHaveBeenCalled()
          options = atom.inbox.makeRequest.mostRecentCall.args[0]
          expect(options.returnsModel).toBe(false)

    it "should swap the ids if we got a new one from the DB", ->
      task = new SaveDraftTask("localDraftId")
      waitsForPromise =>
        task.performRemote().then ->
          expect(DatabaseStore.swapModel).toHaveBeenCalled()
          expect(DatabaseStore.persistModel).not.toHaveBeenCalled()

    it "should not swap the ids if we're using a persisted one", ->
      task = new SaveDraftTask("remoteDraftId")
      waitsForPromise =>
        task.performRemote().then ->
          expect(DatabaseStore.swapModel).not.toHaveBeenCalled()
          expect(DatabaseStore.persistModel).toHaveBeenCalled()

  describe "When the api throws a 404 error", ->
    beforeEach ->
      spyOn(atom.inbox, "makeRequest").andCallFake (opts) ->
        opts.error(testError(opts)) if opts.error

    it "resets the id", ->
      task = new SaveDraftTask("remoteDraftId")
      waitsForPromise shouldReject: true, =>
        promise = task.performRemote()
        promise.catch (apiError) ->
          newDraft = DatabaseStore.swapModel.mostRecentCall.args[0].newModel
          expect(apiError instanceof APIError).toBe true
          expect(apiError.statusCode).toBe 404
          expect(isTempId(newDraft.id)).toBe true
        promise

    it "shouldRetry", ->
      task = new SaveDraftTask("remoteDraftId")
      expect(task.shouldRetry(testError())).toBe true
