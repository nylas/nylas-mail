_ = require 'underscore-plus'
NylasLongConnection = require '../src/flux/nylas-long-connection'
NylasSyncWorker = require '../src/flux/nylas-sync-worker'
Thread = require '../src/flux/models/thread'

describe "NylasSyncWorker", ->
  beforeEach ->
    @apiRequests = []
    @api =
      makeRequest: (requestOptions) =>
        @apiRequests.push({requestOptions})
      getCollection: (namespace, model, params, requestOptions) =>
        @apiRequests.push({namespace, model, params, requestOptions})
      getThreads: (namespace, params, requestOptions) =>
        @apiRequests.push({namespace, model:'threads', params, requestOptions})

    spyOn(atom.config, 'get').andCallFake (key) =>
      expected = "nylas.namespace-id.worker-state"
      return throw new Error("Not stubbed! #{key}") unless key is expected
      return _.extend {}, {
        "contacts":
          busy: true
          complete: false
        "calendars":
          busy:false
          complete: true
      }

    spyOn(atom.config, 'set').andCallFake (key, val) =>
      return

    @worker = new NylasSyncWorker(@api, 'namespace-id')
    @connection = @worker.connection()

  it "should reset `busy` to false when reading state from disk", ->
    state = @worker.state()
    expect(state.contacts.busy).toEqual(false)

  describe "start", ->
    it "should open the long polling connection", ->
      spyOn(@connection, 'start')
      @worker.start()
      expect(@connection.start).toHaveBeenCalled()

    it "should start querying for model collections and counts that haven't been fully cached", ->
      @worker.start()
      expect(@apiRequests.length).toBe(6)
      modelsRequested = _.compact _.map @apiRequests, ({model}) -> model
      expect(modelsRequested).toEqual(['threads', 'contacts', 'files'])

      countsRequested = _.compact _.map @apiRequests, ({requestOptions}) ->
        if requestOptions.qs?.view is 'count'
          return requestOptions.path

      expect(modelsRequested).toEqual(['threads', 'contacts', 'files'])
      expect(countsRequested).toEqual(['/n/namespace-id/threads', '/n/namespace-id/contacts', '/n/namespace-id/files'])

    it "should mark incomplete collections as `busy`", ->
      @worker.start()
      nextState = @worker.state()

      for collection in ['contacts','threads','files']
        expect(nextState[collection].busy).toEqual(true)

    it "should initialize count and fetched to 0", ->
      @worker.start()
      nextState = @worker.state()

      for collection in ['contacts','threads','files']
        expect(nextState[collection].fetched).toEqual(0)
        expect(nextState[collection].count).toEqual(0)

    it "should periodically try to restart failed collection syncs", ->
      spyOn(@worker, 'resumeFetches').andCallThrough()
      @worker.start()
      advanceClock(50000)
      expect(@worker.resumeFetches.callCount).toBe(2)

  describe "when a count request completes", ->
    beforeEach ->
      @worker.start()
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
      expect(@worker.fetchCollection.calls.map (call) -> call.args[0]).toEqual(['threads', 'calendars', 'contacts', 'files'])

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
      expect(@apiRequests[0].requestOptions.path).toBe('/n/namespace-id/threads')
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

  describe "cleanup", ->
    it "should termiate the long polling connection", ->
      spyOn(@connection, 'end')
      @worker.cleanup()
      expect(@connection.end).toHaveBeenCalled()

    it "should stop trying to restart failed collection syncs", ->
      spyOn(@worker, 'resumeFetches').andCallThrough()
      @worker.cleanup()
      advanceClock(50000)
      expect(@worker.resumeFetches.callCount).toBe(0)
