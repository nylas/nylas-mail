_ = require 'underscore'
{Actions, DatabaseStore, DatabaseTransaction, Account, Thread} = require 'nylas-exports'
NylasLongConnection = require '../lib/nylas-long-connection'
NylasSyncWorker = require '../lib/nylas-sync-worker'

describe "NylasSyncWorker", ->
  beforeEach ->
    @apiRequests = []
    @api =
      APIRoot: 'https://api.nylas.com'
      pluginsSupported: true
      accessTokenForAccountId: =>
        '123'
      makeRequest: (requestOptions) =>
        @apiRequests.push({requestOptions})
      getCollection: (account, model, params, requestOptions) =>
        @apiRequests.push({account, model, params, requestOptions})
      getThreads: (account, params, requestOptions) =>
        @apiRequests.push({account, model:'threads', params, requestOptions})

    @apiCursorStub = undefined
    spyOn(NylasSyncWorker.prototype, 'fetchAllMetadata').andCallFake (cb) -> cb()
    spyOn(DatabaseTransaction.prototype, 'persistJSONBlob').andReturn(Promise.resolve())
    spyOn(DatabaseStore, 'findJSONBlob').andCallFake (key) =>
      if key is "NylasSyncWorker:#{TEST_ACCOUNT_ID}"
        return Promise.resolve _.extend {}, {
          "cursor": @apiCursorStub
          "contacts":
            busy: true
            complete: false
          "calendars":
            busy:false
            complete: true
        }
      else if key.indexOf('ContactRankings') is 0
        return Promise.resolve([])
      else
        return throw new Error("Not stubbed! #{key}")


    @account = new Account(clientId: TEST_ACCOUNT_CLIENT_ID, serverId: TEST_ACCOUNT_ID, organizationUnit: 'label')
    @worker = new NylasSyncWorker(@api, @account)
    @worker._metadata = {"a": [{"id":"b"}]}
    @connection = @worker.connection()
    spyOn(@connection, 'start')
    advanceClock()

  it "should reset `busy` to false when reading state from disk", ->
    @worker = new NylasSyncWorker(@api, @account)
    spyOn(@worker, 'resume')
    advanceClock()
    expect(@worker.state().contacts.busy).toEqual(false)

  describe "start", ->
    it "should open the delta connection", ->
      @worker.start()
      advanceClock()
      expect(@connection.start).toHaveBeenCalled()

    it "should start querying for model collections and counts that haven't been fully cached", ->
      @worker.start()
      advanceClock()
      expect(@apiRequests.length).toBe(12)
      modelsRequested = _.compact _.map @apiRequests, ({model}) -> model
      expect(modelsRequested).toEqual(['threads', 'messages', 'labels', 'drafts', 'contacts', 'events'])

      countsRequested = _.compact _.map @apiRequests, ({requestOptions}) ->
        if requestOptions.qs?.view is 'count'
          return requestOptions.path

      expect(modelsRequested).toEqual(['threads', 'messages', 'labels', 'drafts', 'contacts', 'events'])
      expect(countsRequested).toEqual(['/threads', '/messages', '/labels', '/drafts', '/contacts', '/events'])

    it "should fetch 1000 labels and folders, to prevent issues where Inbox is not in the first page", ->
      labelsRequest = _.find @apiRequests, (r) -> r.model is 'labels'
      expect(labelsRequest.params.limit).toBe(1000)

    it "should mark incomplete collections as `busy`", ->
      @worker.start()
      advanceClock()
      nextState = @worker.state()

      for collection in ['contacts','threads','drafts', 'labels']
        expect(nextState[collection].busy).toEqual(true)

    it "should initialize count and fetched to 0", ->
      @worker.start()
      advanceClock()
      nextState = @worker.state()

      for collection in ['contacts','threads','drafts', 'labels']
        expect(nextState[collection].fetched).toEqual(0)
        expect(nextState[collection].count).toEqual(0)

    it "after failures, it should attempt to resume periodically but back off as failures continue", ->
      simulateNetworkFailure = =>
        @apiRequests[1].requestOptions.error({statusCode: 400})
        @apiRequests = []

      spyOn(@worker, 'resume').andCallThrough()
      @worker.start()

      expect(@worker.resume.callCount).toBe(1)
      simulateNetworkFailure(); expect(@worker.resume.callCount).toBe(1)
      advanceClock(30000); expect(@worker.resume.callCount).toBe(2)
      simulateNetworkFailure(); expect(@worker.resume.callCount).toBe(2)
      advanceClock(30000); expect(@worker.resume.callCount).toBe(2)
      advanceClock(30000); expect(@worker.resume.callCount).toBe(3)
      simulateNetworkFailure(); expect(@worker.resume.callCount).toBe(3)
      advanceClock(30000); expect(@worker.resume.callCount).toBe(3)
      advanceClock(30000); expect(@worker.resume.callCount).toBe(4)
      simulateNetworkFailure(); expect(@worker.resume.callCount).toBe(4)
      advanceClock(30000); expect(@worker.resume.callCount).toBe(4)
      advanceClock(30000); expect(@worker.resume.callCount).toBe(4)
      advanceClock(30000); expect(@worker.resume.callCount).toBe(5)

    it "handles the request as a failure if we try and grab labels or folders without an 'inbox'", ->
      spyOn(@worker, 'resume').andCallThrough()
      @worker.start()
      expect(@worker.resume.callCount).toBe(1)
      request = _.findWhere(@apiRequests, model: 'labels')
      request.requestOptions.success([])
      expect(@worker.resume.callCount).toBe(1)
      advanceClock(30000)
      expect(@worker.resume.callCount).toBe(2)

    it "handles the request as a success if we try and grab labels or folders and it includes the 'inbox'", ->
      spyOn(@worker, 'resume').andCallThrough()
      @worker.start()
      expect(@worker.resume.callCount).toBe(1)
      request = _.findWhere(@apiRequests, model: 'labels')
      request.requestOptions.success([{name: "inbox"}, {name: "archive"}])
      expect(@worker.resume.callCount).toBe(1)
      advanceClock(30000)
      expect(@worker.resume.callCount).toBe(1)

  describe "delta streaming cursor", ->
    it "should read the cursor from the database, and the old config format", ->
      spyOn(NylasLongConnection.prototype, 'withCursor').andCallFake =>

      @apiCursorStub = undefined

      # no cursor present
      worker = new NylasSyncWorker(@api, @account)
      connection = worker.connection()
      expect(connection.hasCursor()).toBe(false)
      advanceClock()
      expect(connection.hasCursor()).toBe(false)

      # cursor present in config
      spyOn(NylasEnv.config, 'get').andCallFake (key) =>
        return 'old-school' if key is "nylas.#{@account.id}.cursor"
        return undefined

      worker = new NylasSyncWorker(@api, @account)
      connection = worker.connection()
      advanceClock()
      expect(connection.hasCursor()).toBe(true)
      expect(connection._config.getCursor()).toEqual('old-school')

      # cursor present in database, overrides cursor in config
      @apiCursorStub = "new-school"

      worker = new NylasSyncWorker(@api, @account)
      connection = worker.connection()
      expect(connection.hasCursor()).toBe(false)
      advanceClock()
      expect(connection.hasCursor()).toBe(true)
      expect(connection._config.getCursor()).toEqual('new-school')

  describe "when a count request completes", ->
    beforeEach ->
      @worker.start()
      advanceClock()
      @request = @apiRequests[0]
      @apiRequests = []

    it "should update the count on the collection", ->
      @request.requestOptions.success({count: 1001})
      nextState = @worker.state()
      expect(nextState.threads.count).toEqual(1001)

  describe "resume", ->
    it "should fetch metadata first and fetch other collections when metadata is ready", ->
      fetchAllMetadataCallback = null
      jasmine.unspy(NylasSyncWorker.prototype, 'fetchAllMetadata')
      spyOn(NylasSyncWorker.prototype, 'fetchAllMetadata').andCallFake (cb) =>
        fetchAllMetadataCallback = cb
      spyOn(@worker, 'fetchCollection')
      @worker._state = {}
      @worker.resume()
      expect(@worker.fetchAllMetadata).toHaveBeenCalled()
      expect(@worker.fetchCollection.calls.length).toBe(0)
      fetchAllMetadataCallback()
      expect(@worker.fetchCollection.calls.length).not.toBe(0)

    it "should not fetch metadata pages if pluginsSupported is false", ->
      @api.pluginsSupported = false
      spyOn(NylasSyncWorker.prototype, '_fetchWithErrorHandling')
      spyOn(@worker, 'fetchCollection')
      @worker._state = {}
      @worker.resume()
      expect(@worker._fetchWithErrorHandling).not.toHaveBeenCalled()
      expect(@worker.fetchCollection.calls.length).not.toBe(0)

    it "should fetch collections for which `shouldFetchCollection` returns true", ->
      spyOn(@worker, 'fetchCollection')
      spyOn(@worker, 'shouldFetchCollection').andCallFake (collection) =>
        return collection in ['threads', 'labels', 'drafts']
      @worker.resume()
      expect(@worker.fetchCollection.calls.map (call) -> call.args[0]).toEqual(['threads', 'labels', 'drafts'])

    it "should be called when Actions.retrySync is received", ->
      spyOn(@worker, 'resume').andCallThrough()
      Actions.retrySync()
      expect(@worker.resume).toHaveBeenCalled()

  describe "shouldFetchCollection", ->
    it "should return false if the collection sync is already in progress", ->
      @worker._state.threads = {
        'busy': true
        'complete': false
      }
      expect(@worker.shouldFetchCollection('threads')).toBe(false)

    it "should return false if the collection sync is already complete", ->
      @worker._state.threads = {
        'busy': false
        'complete': true
      }
      expect(@worker.shouldFetchCollection('threads')).toBe(false)

    it "should return true otherwise", ->
      @worker._state.threads = {
        'busy': false
        'complete': false
      }
      expect(@worker.shouldFetchCollection('threads')).toBe(true)
      @worker._state.threads = undefined
      expect(@worker.shouldFetchCollection('threads')).toBe(true)

  describe "fetchCollection", ->
    beforeEach ->
      @apiRequests = []

    it "should start the request for the model count", ->
      @worker._state.threads = {
        'busy': false
        'complete': false
      }
      @worker.fetchCollection('threads')
      expect(@apiRequests[0].requestOptions.path).toBe('/threads')
      expect(@apiRequests[0].requestOptions.qs.view).toBe('count')

    it "should pass any metadata it preloaded", ->
      @worker._state.threads = {
        'busy': false
        'complete': false
      }
      @worker.fetchCollection('threads')
      expect(@apiRequests[1].model).toBe('threads')
      expect(@apiRequests[1].requestOptions.metadataToAttach).toBe(@worker._metadata)

    describe "when there is not a previous page failure (`errorRequestRange`)", ->
      it "should start the first request for models", ->
        @worker._state.threads = {
          'busy': false
          'complete': false
        }
        @worker.fetchCollection('threads')
        expect(@apiRequests[1].model).toBe('threads')
        expect(@apiRequests[1].params.offset).toBe(0)

    describe "when there is a previous page failure (`errorRequestRange`)", ->
      beforeEach ->
        @worker._state.threads =
          'count': 1200
          'fetched': 100
          'busy': false
          'complete': false
          'error': new Error("Something bad")
          'errorRequestRange':
            offset: 100
            limit: 50

      it "should start paginating from the request that failed", ->
        @worker.fetchCollection('threads')
        expect(@apiRequests[0].model).toBe('threads')
        expect(@apiRequests[0].params.offset).toBe(100)
        expect(@apiRequests[0].params.limit).toBe(50)

      it "should not reset the `count`, `fetched` or start fetching the count", ->
        @worker.fetchCollection('threads')
        expect(@worker._state.threads.fetched).toBe(100)
        expect(@worker._state.threads.count).toBe(1200)
        expect(@apiRequests.length).toBe(1)

    describe 'when maxFetchCount option is specified', ->
      it "should only fetch maxFetch count on the first request if it is less than initialPageSize", ->
        @worker._state.messages =
          count: 1000
          fetched: 0
        @worker.fetchCollection('messages', {initialPageSize: 30, maxFetchCount: 25})
        expect(@apiRequests[0].params.offset).toBe 0
        expect(@apiRequests[0].params.limit).toBe 25

      it "sould only fetch the maxFetchCount when restoring from saved state", ->
        @worker._state.messages =
          count: 1000
          fetched: 470
          errorRequestRange: {
            limit: 50,
            offset: 470,
          }
        @worker.fetchCollection('messages', {maxFetchCount: 500})
        expect(@apiRequests[0].params.offset).toBe 470
        expect(@apiRequests[0].params.limit).toBe 30

  describe "fetchCollectionPage", ->
    beforeEach ->
      @apiRequests = []

    describe 'when maxFetchCount option is specified', ->
      it 'should not fetch next page if maxFetchCount has been reached', ->
        @worker._state.messages =
          count: 1000
          fetched: 470
        @worker.fetchCollectionPage('messages', {limit: 30, offset: 470}, {maxFetchCount: 500})
        {success} = @apiRequests[0].requestOptions
        success({length: 30})
        expect(@worker._state.messages.fetched).toBe 500
        advanceClock(2000)
        expect(@apiRequests.length).toBe 1

      it 'should limit by maxFetchCount when requesting the next page', ->
        @worker._state.messages =
          count: 1000
          fetched: 450
        @worker.fetchCollectionPage('messages', {limit: 30, offset: 450 }, {maxFetchCount: 500})
        {success} = @apiRequests[0].requestOptions
        success({length: 30})
        expect(@worker._state.messages.fetched).toBe 480
        advanceClock(2000)
        expect(@apiRequests[1].params.offset).toBe 480
        expect(@apiRequests[1].params.limit).toBe 20

  describe "when an API request completes", ->
    beforeEach ->
      @worker.start()
      advanceClock()
      @request = @apiRequests[1]
      @apiRequests = []

    describe "successfully, with models", ->
      it "should start out by requesting a small number of items", ->
        expect(@request.params.limit).toBe NylasSyncWorker.INITIAL_PAGE_SIZE

      it "should request the next page", ->
        pageSize = @request.params.limit
        models = []
        models.push(new Thread) for i in [0..(pageSize-1)]
        @request.requestOptions.success(models)
        advanceClock(2000)
        expect(@apiRequests.length).toBe(1)
        expect(@apiRequests[0].params.offset).toEqual @request.params.offset + pageSize

      it "increase the limit on the next page load by 50%", ->
        pageSize = @request.params.limit
        models = []
        models.push(new Thread) for i in [0..(pageSize-1)]
        @request.requestOptions.success(models)
        advanceClock(2000)
        expect(@apiRequests.length).toBe(1)
        expect(@apiRequests[0].params.limit).toEqual pageSize * 1.5,

      it "never requests more then MAX_PAGE_SIZE", ->
        pageSize = @request.params.limit = NylasSyncWorker.MAX_PAGE_SIZE
        models = []
        models.push(new Thread) for i in [0..(pageSize-1)]
        @request.requestOptions.success(models)
        advanceClock(2000)
        expect(@apiRequests.length).toBe(1)
        expect(@apiRequests[0].params.limit).toEqual NylasSyncWorker.MAX_PAGE_SIZE

      it "should update the fetched count on the collection", ->
        expect(@worker.state().threads.fetched).toEqual(0)
        pageSize = @request.params.limit
        models = []
        models.push(new Thread) for i in [0..(pageSize-1)]
        @request.requestOptions.success(models)
        expect(@worker.state().threads.fetched).toEqual(pageSize)

    describe "successfully, with fewer models than requested", ->
      beforeEach ->
        models = []
        models.push(new Thread) for i in [0..100]
        @request.requestOptions.success(models)

      it "should not request another page", ->
        expect(@apiRequests.length).toBe(0)

      it "should update the state to complete", ->
        expect(@worker.state().threads.busy).toEqual(false)
        expect(@worker.state().threads.complete).toEqual(true)

      it "should update the fetched count on the collection", ->
        expect(@worker.state().threads.fetched).toEqual(101)

    describe "successfully, with no models", ->
      it "should not request another page", ->
        @request.requestOptions.success([])
        expect(@apiRequests.length).toBe(0)

      it "should update the state to complete", ->
        @request.requestOptions.success([])
        expect(@worker.state().threads.busy).toEqual(false)
        expect(@worker.state().threads.complete).toEqual(true)

    describe "with an error", ->
      it "should log the error to the state, along with the range that failed", ->
        err = new Error("Oh no a network error")
        @request.requestOptions.error(err)
        expect(@worker.state().threads.busy).toEqual(false)
        expect(@worker.state().threads.complete).toEqual(false)
        expect(@worker.state().threads.error).toEqual(err.toString())
        expect(@worker.state().threads.errorRequestRange).toEqual({offset: 0, limit: 30})

      it "should not request another page", ->
        @request.requestOptions.error(new Error("Oh no a network error"))
        expect(@apiRequests.length).toBe(0)

    describe "succeeds after a previous error", ->
      beforeEach ->
        @worker._state.threads.error = new Error("Something bad happened")
        @worker._state.threads.errorRequestRange = {limit: 10, offset: 10}
        @request.requestOptions.success([])
        advanceClock(1)

      it "should clear any previous error", ->
        expect(@worker.state().threads.error).toEqual(null)
        expect(@worker.state().threads.errorRequestRange).toEqual(null)

  describe "cleanup", ->
    it "should termiate the delta connection", ->
      spyOn(@connection, 'end')
      @worker.cleanup()
      expect(@connection.end).toHaveBeenCalled()

    it "should stop trying to restart failed collection syncs", ->
      spyOn(console, 'log')
      spyOn(@worker, 'resume').andCallThrough()
      @worker.cleanup()
      advanceClock(50000)
      expect(@worker.resume.callCount).toBe(0)
