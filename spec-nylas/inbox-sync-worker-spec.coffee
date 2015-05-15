_ = require 'underscore-plus'
NylasLongConnection = require '../src/flux/nylas-long-connection'
NylasSyncWorker = require '../src/flux/nylas-sync-worker'
Thread = require '../src/flux/models/thread'

describe "NylasSyncWorker", ->
  beforeEach ->
    @apiRequests = []
    @api =
      getCollection: (namespace, model, params, requestOptions) =>
        @apiRequests.push({namespace, model, params, requestOptions})
      getThreads: (namespace, params, requestOptions) =>
        @apiRequests.push({namespace, model:'threads', params, requestOptions})

    @state =
      "contacts": {busy: true}
      "calendars": {complete: true}

    spyOn(atom.config, 'get').andCallFake (key) =>
      expected = "nylas.namespace-id.worker-state"
      return throw new Error("Not stubbed!") unless key is expected
      return @state

    spyOn(atom.config, 'set').andCallFake (key, val) =>
      expected = "nylas.namespace-id.worker-state"
      return throw new Error("Not stubbed!") unless key is expected
      @state = val

    @worker = new NylasSyncWorker(@api, 'namespace-id')
    @connection = @worker.connection()

  describe "start", ->
    it "should open the long polling connection", ->
      spyOn(@connection, 'start')
      @worker.start()
      expect(@connection.start).toHaveBeenCalled()

    it "should start querying for model collections that haven't been fully cached", ->
      @worker.start()
      expect(@apiRequests.length).toBe(3)
      modelsRequested = _.map @apiRequests, (r) -> r.model
      expect(modelsRequested).toEqual(['threads', 'contacts', 'files'])

    it "should mark incomplete collections as `busy`", ->
      @worker.start()
      expect(@state).toEqual({
        "contacts": {busy: true}
        "threads": {busy: true}
        "files": {busy: true}
        "calendars": {complete: true}
      })

  describe "when an API request completes", ->
    beforeEach ->
      @worker.start()
      @request = @apiRequests[0]
      @apiRequests = []

    describe "successfully, with models", ->
      it "should request the next page", ->
        models = []
        models.push(new Thread) for i in [0..249]
        @request.requestOptions.success(models)
        expect(@apiRequests.length).toBe(1)
        expect(@apiRequests[0].params).toEqual({limit:250; offset: 250})

    describe "successfully, with fewer models than requested", ->
      beforeEach ->
        models = []
        models.push(new Thread) for i in [0..100]
        @request.requestOptions.success(models)

      it "should not request another page", ->
        @request.requestOptions.success([])
        expect(@apiRequests.length).toBe(0)

      it "should update the state to complete", ->
        @request.requestOptions.success([])
        expect(@state).toEqual({
          "contacts": {busy: true}
          "files": {busy: true}
          "threads": {complete : true}
          "calendars": {complete: true}
        })

    describe "successfully, with no models", ->
      it "should not request another page", ->
        @request.requestOptions.success([])
        expect(@apiRequests.length).toBe(0)

      it "should update the state to complete", ->
        @request.requestOptions.success([])
        expect(@state).toEqual({
          "contacts": {busy: true}
          "files": {busy: true}
          "threads": {complete : true}
          "calendars": {complete: true}
        })

    describe "with an error", ->
      it "should log the error to the state", ->
        err = new Error("Oh no a network error")
        @request.requestOptions.error(err)
        expect(@state).toEqual({
          "contacts": {busy: true}
          "files": {busy: true}
          "threads": {busy: false, error: err.toString()}
          "calendars": {complete: true}
        })

      it "should not request another page", ->
        @request.requestOptions.error(new Error("Oh no a network error"))
        expect(@apiRequests.length).toBe(0)

  describe "cleanup", ->
    it "should termiate the long polling connection", ->
      spyOn(@connection, 'end')
      @worker.cleanup()
      expect(@connection.end).toHaveBeenCalled()
