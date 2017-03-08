_ = require 'underscore'
{NylasAPI, NylasAPIHelpers, NylasAPIRequest, Actions, DatabaseStore, DatabaseTransaction, Account, Thread} = require 'nylas-exports'
DeltaStreamingConnection = require('../../src/services/delta-streaming-connection').default

# TODO these are badly out of date, we need to rewrite them
xdescribe "DeltaStreamingConnection", ->
  beforeEach ->
    @apiRequests = []
    spyOn(NylasAPIRequest.prototype, "run").andCallFake ->
      @apiRequests.push({requestOptions: this.options})
    @localSyncCursorStub = undefined
    @n1CloudCursorStub = undefined
    # spyOn(DeltaStreamingConnection.prototype, '_fetchMetadata').andReturn(Promise.resolve())
    spyOn(DatabaseTransaction.prototype, 'persistJSONBlob').andReturn(Promise.resolve())
    spyOn(DatabaseStore, 'findJSONBlob').andCallFake (key) =>
      if key is "NylasSyncWorker:#{TEST_ACCOUNT_ID}"
        return Promise.resolve _.extend {}, {
          "deltaCursors": {
            "localSync": @localSyncCursorStub,
            "n1Cloud": @n1CloudCursorStub,
          }
          "initialized": true,
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


    spyOn(DeltaStreamingConnection.prototype, 'start')
    @account = new Account(clientId: TEST_ACCOUNT_CLIENT_ID, serverId: TEST_ACCOUNT_ID, organizationUnit: 'label')
    @worker = new DeltaStreamingConnection(@account)
    @worker.loadStateFromDatabase()
    advanceClock()
    @worker.start()
    @worker._metadata = {"a": [{"id":"b"}]}
    @deltaStreams = @worker._deltaStreams
    advanceClock()

  it "should reset `busy` to false when reading state from disk", ->
    @worker = new DeltaStreamingConnection(@account)
    spyOn(@worker, '_resume')
    @worker.loadStateFromDatabase()
    advanceClock()
    expect(@worker._state.contacts.busy).toEqual(false)

  describe "start", ->
    it "should open the delta connection", ->
      @worker.start()
      advanceClock()
      expect(@deltaStreams.localSync.start).toHaveBeenCalled()
      expect(@deltaStreams.n1Cloud.start).toHaveBeenCalled()

    it "should start querying for model collections that haven't been fully cached", ->
      waitsForPromise => @worker.start().then =>
        expect(@apiRequests.length).toBe(7)
        modelsRequested = _.compact _.map @apiRequests, ({model}) -> model
        expect(modelsRequested).toEqual(['threads', 'messages', 'folders', 'labels', 'drafts', 'contacts', 'events'])

        expect(modelsRequested).toEqual(['threads', 'messages', 'folders', 'labels', 'drafts', 'contacts', 'events'])

    it "should fetch 1000 labels and folders, to prevent issues where Inbox is not in the first page", ->
      labelsRequest = _.find @apiRequests, (r) -> r.model is 'labels'
      expect(labelsRequest.params.limit).toBe(1000)

    it "should mark incomplete collections as `busy`", ->
      @worker.start()
      advanceClock()
      nextState = @worker._state

      for collection in ['contacts','threads','drafts', 'labels']
        expect(nextState[collection].busy).toEqual(true)

    it "should initialize count and fetched to 0", ->
      @worker.start()
      advanceClock()
      nextState = @worker._state

      for collection in ['contacts','threads','drafts', 'labels']
        expect(nextState[collection].fetched).toEqual(0)
        expect(nextState[collection].count).toEqual(0)

    it "after failures, it should attempt to resume periodically but back off as failures continue", ->
      simulateNetworkFailure = =>
        @apiRequests[0].requestOptions.error({statusCode: 400})
        @apiRequests = []

      spyOn(@worker, '_resume').andCallThrough()
      spyOn(Math, 'random').andReturn(1.0)
      @worker.start()

      expectThings = (resumeCallCount, randomCallCount) =>
        expect(@worker._resume.callCount).toBe(resumeCallCount)
        expect(Math.random.callCount).toBe(randomCallCount)

      expect(@worker._resume.callCount).toBe(1, 1)
      simulateNetworkFailure(); expectThings(1, 1)
      advanceClock(4000); advanceClock();       expectThings(2, 1)
      simulateNetworkFailure(); expectThings(2, 2)
      advanceClock(4000); advanceClock();       expectThings(2, 2)
      advanceClock(4000); advanceClock();       expectThings(3, 2)
      simulateNetworkFailure(); expectThings(3, 3)
      advanceClock(4000); advanceClock();       expectThings(3, 3)
      advanceClock(4000); advanceClock();       expectThings(3, 3)
      advanceClock(4000); advanceClock();       expectThings(4, 3)
      simulateNetworkFailure(); expectThings(4, 4)
      advanceClock(4000); advanceClock();       expectThings(4, 4)
      advanceClock(4000); advanceClock();       expectThings(4, 4)
      advanceClock(4000); advanceClock();       expectThings(4, 4)
      advanceClock(4000); advanceClock();       expectThings(4, 4)
      advanceClock(4000); advanceClock();       expectThings(5, 4)

    it "handles the request as a failure if we try and grab labels or folders without an 'inbox'", ->
      spyOn(@worker, '_resume').andCallThrough()
      @worker.start()
      expect(@worker._resume.callCount).toBe(1)
      request = _.findWhere(@apiRequests, model: 'labels')
      request.requestOptions.success([])
      expect(@worker._resume.callCount).toBe(1)
      advanceClock(30000); advanceClock()
      expect(@worker._resume.callCount).toBe(2)

    it "handles the request as a success if we try and grab labels or folders and it includes the 'inbox'", ->
      spyOn(@worker, '_resume').andCallThrough()
      @worker.start()
      expect(@worker._resume.callCount).toBe(1)
      request = _.findWhere(@apiRequests, model: 'labels')
      request.requestOptions.success([{name: "inbox"}, {name: "archive"}])
      expect(@worker._resume.callCount).toBe(1)
      advanceClock(30000); advanceClock()
      expect(@worker._resume.callCount).toBe(1)

  describe "delta streaming cursor", ->
    it "should read the cursor from the database", ->
      spyOn(DeltaStreamingConnection.prototype, 'latestCursor').andReturn Promise.resolve()

      @localSyncCursorStub = undefined
      @n1CloudCursorStub = undefined

      # no cursor present
      worker = new DeltaStreamingConnection(@account)
      deltaStreams = worker._deltaStreams
      expect(deltaStreams.localSync.hasCursor()).toBe(false)
      expect(deltaStreams.n1Cloud.hasCursor()).toBe(false)
      worker.loadStateFromDatabase()
      advanceClock()
      expect(deltaStreams.localSync.hasCursor()).toBe(false)
      expect(deltaStreams.n1Cloud.hasCursor()).toBe(false)

      # cursor present in database
      @localSyncCursorStub = "new-school"
      @n1CloudCursorStub = 123

      worker = new DeltaStreamingConnection(@account)
      deltaStreams = worker._deltaStreams
      expect(deltaStreams.localSync.hasCursor()).toBe(false)
      expect(deltaStreams.n1Cloud.hasCursor()).toBe(false)
      worker.loadStateFromDatabase()
      advanceClock()
      expect(deltaStreams.localSync.hasCursor()).toBe(true)
      expect(deltaStreams.n1Cloud.hasCursor()).toBe(true)
      expect(deltaStreams.localSync._getCursor()).toEqual('new-school')
      expect(deltaStreams.n1Cloud._getCursor()).toEqual(123)

    it "should set the cursor to the last cursor after receiving deltas", ->
      spyOn(DeltaStreamingConnection.prototype, 'latestCursor').andReturn Promise.resolve()
      worker = new DeltaStreamingConnection(@account)
      advanceClock()
      deltaStreams = worker._deltaStreams
      deltas = [{cursor: '1'}, {cursor: '2'}]
      deltaStreams.localSync._emitter.emit('results-stopped-arriving', deltas)
      deltaStreams.n1Cloud._emitter.emit('results-stopped-arriving', deltas)
      advanceClock()
      expect(deltaStreams.localSync._getCursor()).toEqual('2')
      expect(deltaStreams.n1Cloud._getCursor()).toEqual('2')

  describe "_resume", ->
    it "should fetch metadata first and fetch other collections when metadata is ready", ->
      fetchAllMetadataCallback = null
      spyOn(@worker, '_fetchCollectionPage')
      @worker._state = {}
      @worker._resume()
      expect(@worker._fetchMetadata).toHaveBeenCalled()
      expect(@worker._fetchCollectionPage.calls.length).toBe(0)
      advanceClock()
      expect(@worker._fetchCollectionPage.calls.length).not.toBe(0)

    it "should fetch collections for which `_shouldFetchCollection` returns true", ->
      spyOn(@worker, '_fetchCollectionPage')
      spyOn(@worker, '_shouldFetchCollection').andCallFake (collection) =>
        return collection.model in ['threads', 'labels', 'drafts']
      @worker._resume()
      advanceClock()
      advanceClock()
      expect(@worker._fetchCollectionPage.calls.map (call) -> call.args[0]).toEqual(['threads', 'labels', 'drafts'])

    it "should be called when Actions.retryDeltaConnection is received", ->
      spyOn(DeltaStreamingConnection.prototype, 'latestCursor').andReturn Promise.resolve()

      # TODO why do we need to call through?
      spyOn(@worker, '_resume').andCallThrough()
      Actions.retryDeltaConnection()
      expect(@worker._resume).toHaveBeenCalled()

  describe "_shouldFetchCollection", ->
    it "should return false if the collection sync is already in progress", ->
      @worker._state.threads = {
        'busy': true
        'complete': false
      }
      expect(@worker._shouldFetchCollection({model: 'threads'})).toBe(false)

    it "should return false if the collection sync is already complete", ->
      @worker._state.threads = {
        'busy': false
        'complete': true
      }
      expect(@worker._shouldFetchCollection({model: 'threads'})).toBe(false)

    it "should return true otherwise", ->
      @worker._state.threads = {
        'busy': false
        'complete': false
      }
      expect(@worker._shouldFetchCollection({model: 'threads'})).toBe(true)
      @worker._state.threads = undefined
      expect(@worker._shouldFetchCollection({model: 'threads'})).toBe(true)

  describe "_fetchCollection", ->
    beforeEach ->
      @apiRequests = []

    it "should pass any metadata it preloaded", ->
      @worker._state.threads = {
        'busy': false
        'complete': false
      }
      @worker._fetchCollection({model: 'threads'})
      expect(@apiRequests[0].model).toBe('threads')
      expect(@apiRequests[0].requestOptions.metadataToAttach).toBe(@worker._metadata)

    describe "when there is no request history (`lastRequestRange`)", ->
      it "should start the first request for models", ->
        @worker._state.threads = {
          'busy': false
          'complete': false
        }
        @worker._fetchCollection({model: 'threads'})
        expect(@apiRequests[0].model).toBe('threads')
        expect(@apiRequests[0].params.offset).toBe(0)

    describe "when it was previously trying to fetch a page (`lastRequestRange`)", ->
      beforeEach ->
        @worker._state.threads =
          'count': 1200
          'fetched': 100
          'busy': false
          'complete': false
          'error': new Error("Something bad")
          'lastRequestRange':
            offset: 100
            limit: 50

      it "should start paginating from the request that was interrupted", ->
        @worker._fetchCollection({model: 'threads'})
        expect(@apiRequests[0].model).toBe('threads')
        expect(@apiRequests[0].params.offset).toBe(100)
        expect(@apiRequests[0].params.limit).toBe(50)

      it "should not reset the `count`, `fetched` or start fetching the count", ->
        @worker._fetchCollection({model: 'threads'})
        expect(@worker._state.threads.fetched).toBe(100)
        expect(@worker._state.threads.count).toBe(1200)
        expect(@apiRequests.length).toBe(1)

    describe 'when maxFetchCount option is specified', ->
      it "should only fetch maxFetch count on the first request if it is less than initialPageSize", ->
        @worker._state.messages =
          count: 1000
          fetched: 0
        @worker._fetchCollection({model: 'messages', initialPageSize: 30, maxFetchCount: 25})
        expect(@apiRequests[0].params.offset).toBe 0
        expect(@apiRequests[0].params.limit).toBe 25

      it "sould only fetch the maxFetchCount when restoring from saved state", ->
        @worker._state.messages =
          count: 1000
          fetched: 470
          lastRequestRange: {
            limit: 50,
            offset: 470,
          }
        @worker._fetchCollection({model: 'messages', maxFetchCount: 500})
        expect(@apiRequests[0].params.offset).toBe 470
        expect(@apiRequests[0].params.limit).toBe 30

  describe "_fetchCollectionPage", ->
    beforeEach ->
      @apiRequests = []

    describe 'when maxFetchCount option is specified', ->
      it 'should not fetch next page if maxFetchCount has been reached', ->
        @worker._state.messages =
          count: 1000
          fetched: 470
        @worker._fetchCollectionPage('messages', {limit: 30, offset: 470}, {maxFetchCount: 500})
        {success} = @apiRequests[0].requestOptions
        success({length: 30})
        expect(@worker._state.messages.fetched).toBe 500
        advanceClock(2000); advanceClock()
        expect(@apiRequests.length).toBe 1

      it 'should limit by maxFetchCount when requesting the next page', ->
        @worker._state.messages =
          count: 1000
          fetched: 450
        @worker._fetchCollectionPage('messages', {limit: 30, offset: 450 }, {maxFetchCount: 500})
        {success} = @apiRequests[0].requestOptions
        success({length: 30})
        expect(@worker._state.messages.fetched).toBe 480
        advanceClock(2000); advanceClock()
        expect(@apiRequests[1].params.offset).toBe 480
        expect(@apiRequests[1].params.limit).toBe 20

  describe "when an API request completes", ->
    beforeEach ->
      @worker.start()
      advanceClock()
      @request = @apiRequests[0]
      @apiRequests = []

    describe "successfully, with models", ->
      it "should start out by requesting a small number of items", ->
        expect(@request.params.limit).toBe DeltaStreamingConnection.INITIAL_PAGE_SIZE

      it "should request the next page", ->
        pageSize = @request.params.limit
        models = []
        models.push(new Thread) for i in [0..(pageSize-1)]
        @request.requestOptions.success(models)
        advanceClock(2000); advanceClock()
        expect(@apiRequests.length).toBe(1)
        expect(@apiRequests[0].params.offset).toEqual @request.params.offset + pageSize

      it "increase the limit on the next page load by 50%", ->
        pageSize = @request.params.limit
        models = []
        models.push(new Thread) for i in [0..(pageSize-1)]
        @request.requestOptions.success(models)
        advanceClock(2000); advanceClock()
        expect(@apiRequests.length).toBe(1)
        expect(@apiRequests[0].params.limit).toEqual pageSize * 1.5,

      it "never requests more then MAX_PAGE_SIZE", ->
        pageSize = @request.params.limit = DeltaStreamingConnection.MAX_PAGE_SIZE
        models = []
        models.push(new Thread) for i in [0..(pageSize-1)]
        @request.requestOptions.success(models)
        advanceClock(2000); advanceClock()
        expect(@apiRequests.length).toBe(1)
        expect(@apiRequests[0].params.limit).toEqual DeltaStreamingConnection.MAX_PAGE_SIZE

      it "should update the fetched count on the collection", ->
        expect(@worker._state.threads.fetched).toEqual(0)
        pageSize = @request.params.limit
        models = []
        models.push(new Thread) for i in [0..(pageSize-1)]
        @request.requestOptions.success(models)
        expect(@worker._state.threads.fetched).toEqual(pageSize)

    describe "successfully, with fewer models than requested", ->
      beforeEach ->
        models = []
        models.push(new Thread) for i in [0..100]
        @request.requestOptions.success(models)

      it "should not request another page", ->
        expect(@apiRequests.length).toBe(0)

      it "should update the state to complete", ->
        expect(@worker._state.threads.busy).toEqual(false)
        expect(@worker._state.threads.complete).toEqual(true)

      it "should update the fetched count on the collection", ->
        expect(@worker._state.threads.fetched).toEqual(101)

    describe "successfully, with no models", ->
      it "should not request another page", ->
        @request.requestOptions.success([])
        expect(@apiRequests.length).toBe(0)

      it "should update the state to complete", ->
        @request.requestOptions.success([])
        expect(@worker._state.threads.busy).toEqual(false)
        expect(@worker._state.threads.complete).toEqual(true)

    describe "with an error", ->
      it "should log the error to the state, along with the range that failed", ->
        err = new Error("Oh no a network error")
        @request.requestOptions.error(err)
        expect(@worker._state.threads.busy).toEqual(false)
        expect(@worker._state.threads.complete).toEqual(false)
        expect(@worker._state.threads.error).toEqual(err.toString())
        expect(@worker._state.threads.lastRequestRange).toEqual({offset: 0, limit: 30})

      it "should not request another page", ->
        @request.requestOptions.error(new Error("Oh no a network error"))
        expect(@apiRequests.length).toBe(0)

    describe "succeeds after a previous error", ->
      beforeEach ->
        @worker._state.threads.error = new Error("Something bad happened")
        @worker._state.threads.lastRequestRange = {limit: 10, offset: 10}
        @request.requestOptions.success([])
        advanceClock(1)

      it "should clear any previous error and updates lastRequestRange", ->
        expect(@worker._state.threads.error).toEqual(null)
        expect(@worker._state.threads.lastRequestRange).toEqual({offset: 0, limit: 30})

  describe "cleanup", ->
    it "should termiate the delta connection", ->
      spyOn(@deltaStreams.localSync, 'end')
      spyOn(@deltaStreams.n1Cloud, 'end')
      @worker.cleanup()
      expect(@deltaStreams.localSync.end).toHaveBeenCalled()
      expect(@deltaStreams.n1Cloud.end).toHaveBeenCalled()

    it "should stop trying to restart failed collection syncs", ->
      spyOn(console, 'log')
      spyOn(@worker, '_resume').andCallThrough()
      @worker.cleanup()
      advanceClock(50000); advanceClock()
      expect(@worker._resume.callCount).toBe(0)

