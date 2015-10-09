_ = require 'underscore'
{Actions, DatabaseStore, Account, Thread} = require 'nylas-exports'
NylasLongConnection = require '../lib/nylas-long-connection'
NylasSyncWorker = require '../lib/nylas-sync-worker'

describe "NylasSyncWorker", ->
  beforeEach ->
    @apiRequests = []
    @api =
      accessTokenForAccountId: =>
        '123'
      makeRequest: (requestOptions) =>
        @apiRequests.push({requestOptions})
      getCollection: (account, model, params, requestOptions) =>
        @apiRequests.push({account, model, params, requestOptions})
      getThreads: (account, params, requestOptions) =>
        @apiRequests.push({account, model:'threads', params, requestOptions})

    spyOn(DatabaseStore, 'persistJSONObject').andReturn(Promise.resolve())
    spyOn(DatabaseStore, 'findJSONObject').andCallFake (key) =>
      expected = "NylasSyncWorker:#{TEST_ACCOUNT_ID}"
      return throw new Error("Not stubbed! #{key}") unless key is expected
      Promise.resolve _.extend {}, {
        "contacts":
          busy: true
          complete: false
        "calendars":
          busy:false
          complete: true
      }

    @account = new Account(clientId: TEST_ACCOUNT_CLIENT_ID, serverId: TEST_ACCOUNT_ID, organizationUnit: 'label')
    @worker = new NylasSyncWorker(@api, @account)
    @connection = @worker.connection()
    advanceClock()

  it "should reset `busy` to false when reading state from disk", ->
    @worker = new NylasSyncWorker(@api, @account)
    spyOn(@worker, 'resumeFetches')
    advanceClock()
    expect(@worker.state().contacts.busy).toEqual(false)

  describe "start", ->
    it "should open the long polling connection", ->
      spyOn(@connection, 'start')
      @worker.start()
      advanceClock()
      expect(@connection.start).toHaveBeenCalled()

    it "should start querying for model collections and counts that haven't been fully cached", ->
      spyOn(@connection, 'start')
      @worker.start()
      advanceClock()
      expect(@apiRequests.length).toBe(10)
      modelsRequested = _.compact _.map @apiRequests, ({model}) -> model
      expect(modelsRequested).toEqual(['threads', 'labels', 'drafts', 'contacts', 'events'])

      countsRequested = _.compact _.map @apiRequests, ({requestOptions}) ->
        if requestOptions.qs?.view is 'count'
          return requestOptions.path

      expect(modelsRequested).toEqual(['threads', 'labels', 'drafts', 'contacts', 'events'])
      expect(countsRequested).toEqual(['/threads', '/labels', '/drafts', '/contacts', '/events'])

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

      spyOn(@worker, 'resumeFetches').andCallThrough()
      @worker.start()

      expect(@worker.resumeFetches.callCount).toBe(1)
      simulateNetworkFailure(); expect(@worker.resumeFetches.callCount).toBe(1)
      advanceClock(30000); expect(@worker.resumeFetches.callCount).toBe(2)
      simulateNetworkFailure(); expect(@worker.resumeFetches.callCount).toBe(2)
      advanceClock(30000); expect(@worker.resumeFetches.callCount).toBe(2)
      advanceClock(30000); expect(@worker.resumeFetches.callCount).toBe(3)
      simulateNetworkFailure(); expect(@worker.resumeFetches.callCount).toBe(3)
      advanceClock(30000); expect(@worker.resumeFetches.callCount).toBe(3)
      advanceClock(30000); expect(@worker.resumeFetches.callCount).toBe(4)
      simulateNetworkFailure(); expect(@worker.resumeFetches.callCount).toBe(4)
      advanceClock(30000); expect(@worker.resumeFetches.callCount).toBe(4)
      advanceClock(30000); expect(@worker.resumeFetches.callCount).toBe(4)
      advanceClock(30000); expect(@worker.resumeFetches.callCount).toBe(5)

    it "handles the request as a failure if we try and grab labels or folders without an 'inbox'", ->
      spyOn(@worker, 'resumeFetches').andCallThrough()
      @worker.start()
      expect(@worker.resumeFetches.callCount).toBe(1)
      request = _.findWhere(@apiRequests, model: 'labels')
      request.requestOptions.success([])
      expect(@worker.resumeFetches.callCount).toBe(1)
      advanceClock(30000)
      expect(@worker.resumeFetches.callCount).toBe(2)

    it "handles the request as a success if we try and grab labels or folders and it includes the 'inbox'", ->
      spyOn(@worker, 'resumeFetches').andCallThrough()
      @worker.start()
      expect(@worker.resumeFetches.callCount).toBe(1)
      request = _.findWhere(@apiRequests, model: 'labels')
      request.requestOptions.success([{name: "inbox"}, {name: "archive"}])
      expect(@worker.resumeFetches.callCount).toBe(1)
      advanceClock(30000)
      expect(@worker.resumeFetches.callCount).toBe(1)

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

  describe "resumeFetches", ->
    it "should fetch collections", ->
      spyOn(@worker, 'fetchCollection')
      @worker.resumeFetches()
      expect(@worker.fetchCollection.calls.map (call) -> call.args[0]).toEqual(['threads', 'labels', 'drafts', 'contacts', 'calendars', 'events'])

    it "should be called when Actions.retryInitialSync is received", ->
      spyOn(@worker, 'resumeFetches').andCallThrough()
      Actions.retryInitialSync()
      expect(@worker.resumeFetches).toHaveBeenCalled()

  describe "fetchCollection", ->
    beforeEach ->
      @apiRequests = []

    it "should not start if the collection sync is already in progress", ->
      @worker._state.threads = {
        'busy': true
        'complete': false
      }
      @worker.fetchCollection('threads')
      expect(@apiRequests.length).toBe(0)

    it "should not start if the collection sync is already complete", ->
      @worker._state.threads = {
        'busy': false
        'complete': true
      }
      @worker.fetchCollection('threads')
      expect(@apiRequests.length).toBe(0)

    it "should start the request for the model count", ->
      @worker._state.threads = {
        'busy': false
        'complete': false
      }
      @worker.fetchCollection('threads')
      expect(@apiRequests[0].requestOptions.path).toBe('/threads')
      expect(@apiRequests[0].requestOptions.qs.view).toBe('count')

    describe "when there is no errorRequestRange saved", ->
      it "should start the first request for models", ->
        @worker._state.threads = {
          'busy': false
          'complete': false
        }
        @worker.fetchCollection('threads')
        expect(@apiRequests[1].model).toBe('threads')
        expect(@apiRequests[1].params.offset).toBe(0)

    describe "when there is an errorRequestRange saved", ->
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
    it "should termiate the long polling connection", ->
      spyOn(@connection, 'end')
      @worker.cleanup()
      expect(@connection.end).toHaveBeenCalled()

    it "should stop trying to restart failed collection syncs", ->
      spyOn(console, 'log')
      spyOn(@worker, 'resumeFetches').andCallThrough()
      @worker.cleanup()
      advanceClock(50000)
      expect(@worker.resumeFetches.callCount).toBe(0)
