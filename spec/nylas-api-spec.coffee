_ = require 'underscore'
fs = require 'fs'
Actions = require('../src/flux/actions').default
NylasAPI = require('../src/flux/nylas-api').default
NylasAPIHelpers = require '../src/flux/nylas-api-helpers'
NylasAPIRequest = require('../src/flux/nylas-api-request').default
Thread = require('../src/flux/models/thread').default
Message = require('../src/flux/models/message').default
AccountStore = require('../src/flux/stores/account-store').default
DatabaseStore = require('../src/flux/stores/database-store').default
DatabaseTransaction = require('../src/flux/stores/database-transaction').default

fdescribe "NylasAPI", ->

  describe "handleModel404", ->
    it "should unpersist the model from the cache that was requested", ->
      model = new Thread(id: 'threadidhere')
      spyOn(DatabaseTransaction.prototype, 'unpersistModel')
      spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
        return Promise.resolve(model)
      NylasAPIHelpers.handleModel404("/threads/#{model.id}")
      advanceClock()
      expect(DatabaseStore.find).toHaveBeenCalledWith(Thread, model.id)
      expect(DatabaseTransaction.prototype.unpersistModel).toHaveBeenCalledWith(model)

    it "should not do anything if the model is not in the cache", ->
      spyOn(DatabaseTransaction.prototype, 'unpersistModel')
      spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
        return Promise.resolve(null)
      NylasAPIHelpers.handleModel404("/threads/1234")
      advanceClock()
      expect(DatabaseStore.find).toHaveBeenCalledWith(Thread, '1234')
      expect(DatabaseTransaction.prototype.unpersistModel).not.toHaveBeenCalledWith()

    it "should not do anything bad if it doesn't recognize the class", ->
      spyOn(DatabaseStore, 'find')
      spyOn(DatabaseTransaction.prototype, 'unpersistModel')
      waitsForPromise ->
        NylasAPIHelpers.handleModel404("/asdasdasd/1234")
      runs ->
        expect(DatabaseStore.find).not.toHaveBeenCalled()
        expect(DatabaseTransaction.prototype.unpersistModel).not.toHaveBeenCalled()

    it "should not do anything bad if the endpoint only has a single segment", ->
      spyOn(DatabaseStore, 'find')
      spyOn(DatabaseTransaction.prototype, 'unpersistModel')
      waitsForPromise ->
        NylasAPIHelpers.handleModel404("/account")
      runs ->
        expect(DatabaseStore.find).not.toHaveBeenCalled()
        expect(DatabaseTransaction.prototype.unpersistModel).not.toHaveBeenCalled()

  describe "handleAuthenticationFailure", ->
    it "should put the account in an `invalid` state", ->
      spyOn(Actions, 'updateAccount')
      spyOn(AccountStore, 'tokensForAccountId').andReturn('token')
      NylasAPIHelpers.handleAuthenticationFailure('/threads/1234', 'token')
      expect(Actions.updateAccount).toHaveBeenCalled()
      expect(Actions.updateAccount.mostRecentCall.args).toEqual([AccountStore.accounts()[0].id, {syncState: 'invalid'}])

    it "should not throw an exception if the account cannot be found", ->
      spyOn(Actions, 'updateAccount')
      NylasAPIHelpers.handleAuthenticationFailure('/threads/1234', 'token')
      expect(Actions.updateAccount).not.toHaveBeenCalled()

  describe "handleModelResponse", ->
    beforeEach ->
      spyOn(DatabaseTransaction.prototype, "persistModels").andCallFake (models) ->
        Promise.resolve(models)

    stubDB = ({models, testClass, testMatcher}) ->
      spyOn(DatabaseStore, "findAll").andCallFake (klass)  ->
        testClass?(klass)
        where: (matcher) ->
          testMatcher?(matcher)
          Promise.resolve(models)

    it "should reject if no JSON is provided", ->
      waitsForPromise ->
        NylasAPIHelpers.handleModelResponse()
        .then -> throw new Error("Should reject!")
        .catch (err) ->
          expect(err.message).toEqual "handleModelResponse with no JSON provided"

    it "should resolve if an empty JSON array is provided", ->
      waitsForPromise ->
        NylasAPIHelpers.handleModelResponse([])
        .then (resp) ->
          expect(resp).toEqual []

    describe "if JSON contains objects which are of unknown types", ->
      it "should warn and resolve", ->
        spyOn(console, "warn")
        waitsForPromise ->
          NylasAPIHelpers.handleModelResponse([{id: 'a', object: 'unknown'}])
          .then (resp) ->
            expect(resp).toEqual []
            expect(console.warn).toHaveBeenCalled()
            expect(console.warn.calls.length).toBe 1

    describe "if JSON contains the same object more than once", ->
      beforeEach ->
        stubDB(models: [])
        spyOn(console, "warn")
        @dupes = [
          {id: 'a', object: 'thread'}
          {id: 'a', object: 'thread'}
          {id: 'b', object: 'thread'}
        ]

      it "should warn", ->
        waitsForPromise =>
          NylasAPIHelpers.handleModelResponse(@dupes)
          .then ->
            expect(console.warn).toHaveBeenCalled()
            expect(console.warn.calls.length).toBe 1

      it "should omit duplicates", ->
        waitsForPromise =>
          NylasAPIHelpers.handleModelResponse(@dupes)
          .then ->
            models = DatabaseTransaction.prototype.persistModels.calls[0].args[0]
            expect(models.length).toBe 2
            expect(models[0].id).toBe 'a'
            expect(models[1].id).toBe 'b'

    describe "when items in the JSON are locked and we are not accepting changes to them", ->
      it "should remove locked models from the set", ->
        json = [
          {id: 'a', object: 'thread'}
          {id: 'b', object: 'thread'}
        ]
        spyOn(NylasAPI.lockTracker, "acceptRemoteChangesTo").andCallFake (klass, id) ->
          if id is "a" then return false

        stubDB models: [new Thread(json[1])], testMatcher: (whereMatcher) ->
          expect(whereMatcher.val).toEqual 'b'

        waitsForPromise =>
          NylasAPIHelpers.handleModelResponse(json)
          .then (models) ->
            expect(models.length).toBe 1
            models = DatabaseTransaction.prototype.persistModels.calls[0].args[0]
            expect(models.length).toBe 1
            expect(models[0].id).toBe 'b'

    describe "when updating models", ->
      Message = require('../src/flux/models/message').default
      beforeEach ->
        @json = [
          {id: 'a', object: 'draft', unread: true}
          {id: 'b', object: 'draft', starred: true}
        ]
        @existing = new Message(id: 'b', unread: true)
        stubDB models: [@existing]

      verifyUpdateHappened = (responseModels) ->
        changedModels = DatabaseTransaction.prototype.persistModels.calls[0].args[0]
        expect(changedModels.length).toBe 2
        expect(changedModels[1].id).toBe 'b'
        expect(changedModels[1].starred).toBe true
        # Doesn't override existing values
        expect(changedModels[1].unread).toBe true
        expect(responseModels.length).toBe 2
        expect(responseModels[0].id).toBe 'a'
        expect(responseModels[0].unread).toBe true

      it "updates found models with new data", ->
        waitsForPromise =>
          NylasAPIHelpers.handleModelResponse(@json).then verifyUpdateHappened

      it "updates if the json version is newer", ->
        @existing.version = 9
        @json[1].version = 10
        waitsForPromise =>
          NylasAPIHelpers.handleModelResponse(@json).then verifyUpdateHappened

      verifyUpdateStopped = (responseModels) ->
        changedModels = DatabaseTransaction.prototype.persistModels.calls[0].args[0]
        expect(changedModels.length).toBe 1
        expect(changedModels[0].id).toBe 'a'
        expect(changedModels[0].unread).toBe true
        expect(responseModels.length).toBe 2
        expect(responseModels[1].id).toBe 'b'
        expect(responseModels[1].starred).toBeUndefined()

      it "doesn't update if the json version is older", ->
        @existing.version = 10
        @json[1].version = 9
        waitsForPromise =>
          NylasAPIHelpers.handleModelResponse(@json).then verifyUpdateStopped

      it "doesn't update if it's already sent", ->
        @existing.draft = false
        @json[1].draft = true
        waitsForPromise =>
          NylasAPIHelpers.handleModelResponse(@json).then verifyUpdateStopped

    describe "handling all types of objects", ->
      apiObjectToClassMap =
        "file": require('../src/flux/models/file').default
        "event": require('../src/flux/models/event').default
        "label": require('../src/flux/models/label').default
        "folder": require('../src/flux/models/folder').default
        "thread": require('../src/flux/models/thread').default
        "draft": require('../src/flux/models/message').default
        "account": require('../src/flux/models/account').default
        "message": require('../src/flux/models/message').default
        "contact": require('../src/flux/models/contact').default
        "calendar": require('../src/flux/models/calendar').default

      verifyUpdateHappened = (klass, responseModels) ->
        changedModels = DatabaseTransaction.prototype.persistModels.calls[0].args[0]
        expect(changedModels.length).toBe 2
        expect(changedModels[0].id).toBe 'a'
        expect(changedModels[1].id).toBe 'b'
        expect(changedModels[0] instanceof klass).toBe true
        expect(changedModels[1] instanceof klass).toBe true
        expect(responseModels.length).toBe 2
        expect(responseModels[0].id).toBe 'a'
        expect(responseModels[1].id).toBe 'b'
        expect(responseModels[0] instanceof klass).toBe true
        expect(responseModels[1] instanceof klass).toBe true

      _.forEach apiObjectToClassMap, (klass, type) ->
        it "properly handle the '#{type}' type", ->
          json = [
            {id: 'a', object: type}
            {id: 'b', object: type}
          ]
          stubDB models: [new klass(id: 'b')]

          verifyUpdate = _.partial(verifyUpdateHappened, klass)
          waitsForPromise =>
            NylasAPIHelpers.handleModelResponse(json).then verifyUpdate

  describe "makeDraftDeletionRequest", ->
    it "should make an API request to delete the draft", ->
      draft = new Message(accountId: TEST_ACCOUNT_ID, draft: true, clientId: 'asd', serverId: 'asd')
      spyOn(NylasAPIRequest.prototype, 'run')
      NylasAPIHelpers.makeDraftDeletionRequest(draft)
      expect(NylasAPIRequest.prototype.run).toHaveBeenCalled()
      expect(NylasAPIRequest.prototype.run.callCount).toBe 1
      req = NylasAPIRequest.prototype.run.calls[0].args[0]
      expect(req.path).toBe "/drafts/#{draft.serverId}"
      expect(req.accountId).toBe TEST_ACCOUNT_ID
      expect(req.method).toBe "DELETE"
      expect(req.returnsModel).toBe false

    it "should increment the change tracker, preventing any further deltas about the draft", ->
      draft = new Message(accountId: TEST_ACCOUNT_ID, draft: true, clientId: 'asd', serverId: 'asd')
      spyOn(NylasAPI.prototype, 'incrementRemoteChangeLock')
      NylasAPIHelpers.makeDraftDeletionRequest(draft)
      expect(NylasAPI.incrementRemoteChangeLock).toHaveBeenCalledWith(Message, draft.serverId)

    it "should not return a promise or anything else, to avoid accidentally making things dependent on the request", ->
      draft = new Message(accountId: TEST_ACCOUNT_ID, draft: true, clientId: 'asd', serverId: 'asd')
      a = NylasAPIHelpers.makeDraftDeletionRequest(draft)
      expect(a).toBe(undefined)

    it "should not do anything if the draft is missing a serverId", ->
      draft = new Message(accountId: TEST_ACCOUNT_ID, draft: true, clientId: 'asd', serverId: null)
      spyOn(NylasAPIRequest.prototype, 'run')
      NylasAPIHelpers.makeDraftDeletionRequest(draft)
      expect(NylasAPIRequest.prototype.run).not.toHaveBeenCalled()
