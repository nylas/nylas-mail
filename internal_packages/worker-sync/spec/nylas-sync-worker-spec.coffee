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
      expect(@apiRequests.length).toBe(8)
      modelsRequested = _.compact _.map @apiRequests, ({model}) -> model
      expect(modelsRequested).toEqual(['threads', 'contacts', 'drafts', 'labels'])

      countsRequested = _.compact _.map @apiRequests, ({requestOptions}) ->
        if requestOptions.qs?.view is 'count'
          return requestOptions.path

      expect(modelsRequested).toEqual(['threads', 'contacts', 'drafts', 'labels'])
      expect(countsRequested).toEqual(['/threads', '/contacts', '/drafts', '/labels'])

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
      expect(@worker.fetchCollection.calls.map (call) -> call.args[0]).toEqual(['threads', 'calendars', 'contacts', 'drafts', 'labels'])

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

    it "should start the first request for models", ->
      @worker._state.threads = {
        'busy': false
        'complete': false
      }
      @worker.fetchCollection('threads')
      expect(@apiRequests[1].model).toBe('threads')
      expect(@apiRequests[1].params.offset).toBe(0)

  describe "when an API request completes", ->
    beforeEach ->
      @worker.start()
      advanceClock()
      @request = @apiRequests[1]
      @apiRequests = []

    describe "successfully, with models", ->
      it "should request the next page", ->
        pageSize = @request.params.limit
        models = []
        models.push(new Thread) for i in [0..(pageSize-1)]
        @request.requestOptions.success(models)
        expect(@apiRequests.length).toBe(1)
        expect(@apiRequests[0].params).toEqual
          limit: pageSize,
          offset: @request.params.offset + pageSize

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
      it "should log the error to the state", ->
        err = new Error("Oh no a network error")
        @request.requestOptions.error(err)
        expect(@worker.state().threads.busy).toEqual(false)
        expect(@worker.state().threads.complete).toEqual(false)
        expect(@worker.state().threads.error).toEqual(err.toString())

      it "should not request another page", ->
        @request.requestOptions.error(new Error("Oh no a network error"))
        expect(@apiRequests.length).toBe(0)

    it "resumes when a action forces it to", ->
      err = new Error("Oh no a network error")
      @request.requestOptions.error(err)
      expect(@worker.state().threads.busy).toEqual(false)
      expect(@worker.state().threads.complete).toEqual(false)
      spyOn(@worker, 'resumeFetches').andCallThrough()
      Actions.retryInitialSync()
      expect(@worker.resumeFetches).toHaveBeenCalled()
      expect(@worker.resumeFetches.calls.length).toBe 1
      expect(@worker.state().threads.busy).toEqual(true)
      expect(@worker.state().threads.error).toBe(null)

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
