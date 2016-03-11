_ = require 'underscore'
fs = require 'fs'
Actions = require '../src/flux/actions'
NylasAPI = require '../src/flux/nylas-api'
Thread = require '../src/flux/models/thread'
AccountStore = require '../src/flux/stores/account-store'
DatabaseStore = require '../src/flux/stores/database-store'
DatabaseTransaction = require '../src/flux/stores/database-transaction'

describe "NylasAPI", ->
  describe "authPlugin", ->
    beforeEach ->
      NylasAPI.pluginsSupported = true
      @authGetResponse = null
      @authPostResponse = null
      @error = null
      @resolved = false
      spyOn(NylasEnv.config, 'set')
      spyOn(NylasEnv.config, 'get').andReturn(null)
      spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
        return @authGetResponse if options.method is 'GET' and @authGetResponse
        return @authPostResponse if options.method is 'POST' and @authPostResponse
        return new Promise (resolve, reject) -> #never respond

    it "should reject if the current environment does not support plugins", ->
      NylasAPI.pluginsSupported = false
      NylasAPI.authPlugin('PID', 'PSECRET', TEST_ACCOUNT_ID).catch (err) => @error = err
      waitsFor =>
        @error
      runs =>
        expect(@error.message).toEqual('Sorry, this feature is only available when N1 is running against the hosted version of the Nylas Sync Engine.')

    it "should reject if no account can be found for the given accountOrId", ->
      NylasAPI.authPlugin('PID', 'PSECRET', 'randomAccountId').catch (err) => @error = err
      waitsFor =>
        @error
      runs =>
        expect(@error.message).toEqual('Invalid account')

    it "should resolve if the plugin has been successfully authed with accountOrId already", ->
      jasmine.unspy(NylasEnv.config, 'get')
      spyOn(NylasEnv.config, 'get').andCallFake (key) =>
        return Date.now() if key is "plugins.PID.lastAuth.#{TEST_ACCOUNT_ID}"
        return null
      NylasAPI.authPlugin('PID', 'PSECRET', TEST_ACCOUNT_ID).then (err) =>
        @resolved = true
      waitsFor =>
        @resolved
      expect(NylasAPI.makeRequest).not.toHaveBeenCalled()

    describe "check for existing auth", ->
      it "should GET /auth/plugin to check if the plugin has been authed", ->
        @authGetResponse = Promise.resolve({authed: true})
        NylasAPI.authPlugin('PID', 'PSECRET', TEST_ACCOUNT_ID)
        advanceClock()
        expect(NylasAPI.makeRequest).toHaveBeenCalledWith({
          returnsModel: false,
          method: 'GET',
          accountId: 'test-account-server-id',
          path: '/auth/plugin?client_id=PID'
        })

      it "should record a successful auth in the config and resolve without making a POST", ->
        @authGetResponse = Promise.resolve({authed: true})
        @authPostResponse = null
        NylasAPI.authPlugin('PID', 'PSECRET', TEST_ACCOUNT_ID).then => @resolved = true
        waitsFor =>
          @resolved
        runs =>
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          expect(NylasEnv.config.set.mostRecentCall.args[0]).toEqual("plugins.PID.lastAuth.#{TEST_ACCOUNT_ID}")

      it "should propagate any network errors back to the caller", ->
        @authGetResponse = Promise.reject(new Error("Network failure!"))
        NylasAPI.authPlugin('PID', 'PSECRET', TEST_ACCOUNT_ID).catch (err) => @error = err
        advanceClock()
        advanceClock()
        expect(@error.message).toBe("Network failure!")
        expect(NylasEnv.config.set).not.toHaveBeenCalled()

    describe "request for auth", ->
      it "should POST to /auth/plugin with the client id and record a successful auth", ->
        @authGetResponse = Promise.resolve({authed: false})
        @authPostResponse = Promise.resolve({authed: true})
        NylasAPI.authPlugin('PID', 'PSECRET', TEST_ACCOUNT_ID).then => @resolved = true
        waitsFor =>
          @resolved
        runs =>
          expect(NylasAPI.makeRequest.calls[0].args[0]).toEqual({
            returnsModel: false,
            method: 'GET',
            accountId: 'test-account-server-id',
            path: '/auth/plugin?client_id=PID'
          })
          expect(NylasAPI.makeRequest.calls[1].args[0]).toEqual({
            returnsModel: false,
            method: 'POST',
            accountId: 'test-account-server-id',
            path: '/auth/plugin',
            body: {client_id: 'PID'},
            json: true
          })
          setCall = NylasEnv.config.set.mostRecentCall
          expect(setCall.args[0]).toEqual("plugins.PID.lastAuth.#{TEST_ACCOUNT_ID}")

      it "should propagate any network errors back to the caller", ->
        @authGetResponse = Promise.resolve({authed: false})
        @authPostResponse = Promise.reject(new Error("Network failure!"))
        NylasAPI.authPlugin('PID', 'PSECRET', TEST_ACCOUNT_ID).catch (err) => @error = err
        waitsFor =>
          @error
        runs =>
          expect(@error.message).toBe("Network failure!")

  describe "handleModel404", ->
    it "should unpersist the model from the cache that was requested", ->
      model = new Thread(id: 'threadidhere')
      spyOn(DatabaseTransaction.prototype, 'unpersistModel')
      spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
        return Promise.resolve(model)
      NylasAPI._handleModel404("/threads/#{model.id}")
      advanceClock()
      expect(DatabaseStore.find).toHaveBeenCalledWith(Thread, model.id)
      expect(DatabaseTransaction.prototype.unpersistModel).toHaveBeenCalledWith(model)

    it "should not do anything if the model is not in the cache", ->
      spyOn(DatabaseTransaction.prototype, 'unpersistModel')
      spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
        return Promise.resolve(null)
      NylasAPI._handleModel404("/threads/1234")
      advanceClock()
      expect(DatabaseStore.find).toHaveBeenCalledWith(Thread, '1234')
      expect(DatabaseTransaction.prototype.unpersistModel).not.toHaveBeenCalledWith()

    it "should not do anything bad if it doesn't recognize the class", ->
      spyOn(DatabaseStore, 'find')
      spyOn(DatabaseTransaction.prototype, 'unpersistModel')
      waitsForPromise ->
        NylasAPI._handleModel404("/asdasdasd/1234")
      runs ->
        expect(DatabaseStore.find).not.toHaveBeenCalled()
        expect(DatabaseTransaction.prototype.unpersistModel).not.toHaveBeenCalled()

    it "should not do anything bad if the endpoint only has a single segment", ->
      spyOn(DatabaseStore, 'find')
      spyOn(DatabaseTransaction.prototype, 'unpersistModel')
      waitsForPromise ->
        NylasAPI._handleModel404("/account")
      runs ->
        expect(DatabaseStore.find).not.toHaveBeenCalled()
        expect(DatabaseTransaction.prototype.unpersistModel).not.toHaveBeenCalled()

  describe "handleAuthenticationFailure", ->
    it "should post a notification", ->
      spyOn(Actions, 'postNotification')
      NylasAPI._handleAuthenticationFailure('/threads/1234', 'token')
      expect(Actions.postNotification).toHaveBeenCalled()
      expect(Actions.postNotification.mostRecentCall.args[0].message.trim()).toEqual("Action failed: There was an error syncing with your mail provider. You may not be able to send or receive mail.")

    it "should include the email address if possible", ->
      spyOn(AccountStore, 'tokenForAccountId').andReturn('token')
      spyOn(Actions, 'postNotification')
      NylasAPI._handleAuthenticationFailure('/threads/1234', 'token')
      expect(Actions.postNotification).toHaveBeenCalled()
      expect(Actions.postNotification.mostRecentCall.args[0].message.trim()).toEqual("Action failed: There was an error syncing with #{AccountStore.accounts()[0].emailAddress}. You may not be able to send or receive mail.")

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
        NylasAPI._handleModelResponse()
        .then -> throw new Error("Should reject!")
        .catch (err) ->
          expect(err.message).toEqual "handleModelResponse with no JSON provided"

    it "should resolve if an empty JSON array is provided", ->
      waitsForPromise ->
        NylasAPI._handleModelResponse([])
        .then (resp) ->
          expect(resp).toEqual []

    describe "if JSON contains objects which are of unknown types", ->
      it "should warn and resolve", ->
        spyOn(console, "warn")
        waitsForPromise ->
          NylasAPI._handleModelResponse([{id: 'a', object: 'unknown'}])
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
          NylasAPI._handleModelResponse(@dupes)
          .then ->
            expect(console.warn).toHaveBeenCalled()
            expect(console.warn.calls.length).toBe 1

      it "should omit duplicates", ->
        waitsForPromise =>
          NylasAPI._handleModelResponse(@dupes)
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
        spyOn(NylasAPI._lockTracker, "acceptRemoteChangesTo").andCallFake (klass, id) ->
          if id is "a" then return false

        stubDB models: [new Thread(json[1])], testMatcher: (whereMatcher) ->
          expect(whereMatcher.val).toEqual 'b'

        waitsForPromise =>
          NylasAPI._handleModelResponse(json)
          .then (models) ->
            expect(models.length).toBe 1
            models = DatabaseTransaction.prototype.persistModels.calls[0].args[0]
            expect(models.length).toBe 1
            expect(models[0].id).toBe 'b'

    describe "when updating models", ->
      Message = require '../src/flux/models/message'
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
          NylasAPI._handleModelResponse(@json).then verifyUpdateHappened

      it "updates if the json version is newer", ->
        @existing.version = 9
        @json[1].version = 10
        waitsForPromise =>
          NylasAPI._handleModelResponse(@json).then verifyUpdateHappened

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
          NylasAPI._handleModelResponse(@json).then verifyUpdateStopped

      it "doesn't update if it's already sent", ->
        @existing.draft = false
        @json[1].draft = true
        waitsForPromise =>
          NylasAPI._handleModelResponse(@json).then verifyUpdateStopped

    describe "handling all types of objects", ->
      apiObjectToClassMap =
        "file": require('../src/flux/models/file')
        "event": require('../src/flux/models/event')
        "label": require('../src/flux/models/label')
        "folder": require('../src/flux/models/folder')
        "thread": require('../src/flux/models/thread')
        "draft": require('../src/flux/models/message')
        "account": require('../src/flux/models/account')
        "message": require('../src/flux/models/message')
        "contact": require('../src/flux/models/contact')
        "calendar": require('../src/flux/models/calendar')

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
            NylasAPI._handleModelResponse(json).then verifyUpdate
