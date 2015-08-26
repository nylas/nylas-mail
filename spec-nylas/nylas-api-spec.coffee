_ = require 'underscore'
fs = require 'fs'
Actions = require '../src/flux/actions'
NylasAPI = require '../src/flux/nylas-api'
Thread = require '../src/flux/models/thread'
DatabaseStore = require '../src/flux/stores/database-store'

describe "NylasAPI", ->
  describe "handleModel404", ->
    it "should unpersist the model from the cache that was requested", ->
      model = new Thread(id: 'threadidhere')
      spyOn(DatabaseStore, 'unpersistModel')
      spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
        return Promise.resolve(model)
      NylasAPI._handleModel404("/threads/#{model.id}")
      advanceClock()
      expect(DatabaseStore.find).toHaveBeenCalledWith(Thread, model.id)
      expect(DatabaseStore.unpersistModel).toHaveBeenCalledWith(model)

    it "should not do anything if the model is not in the cache", ->
      spyOn(DatabaseStore, 'unpersistModel')
      spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
        return Promise.resolve(null)
      NylasAPI._handleModel404("/threads/1234")
      advanceClock()
      expect(DatabaseStore.find).toHaveBeenCalledWith(Thread, '1234')
      expect(DatabaseStore.unpersistModel).not.toHaveBeenCalledWith()

    it "should not do anything bad if it doesn't recognize the class", ->
      spyOn(DatabaseStore, 'find')
      spyOn(DatabaseStore, 'unpersistModel')
      waitsForPromise ->
        NylasAPI._handleModel404("/asdasdasd/1234")
      runs ->
        expect(DatabaseStore.find).not.toHaveBeenCalled()
        expect(DatabaseStore.unpersistModel).not.toHaveBeenCalled()

    it "should not do anything bad if the endpoint only has a single segment", ->
      spyOn(DatabaseStore, 'find')
      spyOn(DatabaseStore, 'unpersistModel')
      waitsForPromise ->
        NylasAPI._handleModel404("/account")
      runs ->
        expect(DatabaseStore.find).not.toHaveBeenCalled()
        expect(DatabaseStore.unpersistModel).not.toHaveBeenCalled()

  describe "handle401", ->
    it "should post a notification", ->
      spyOn(Actions, 'postNotification')
      NylasAPI._handle401('/threads/1234')
      expect(Actions.postNotification).toHaveBeenCalled()
      expect(Actions.postNotification.mostRecentCall.args[0].message).toEqual("Nylas can no longer authenticate with your mail provider. You will not be able to send or receive mail. Please log out and sign in again.")

  describe "handleDeltas", ->
    beforeEach ->
      @sampleDeltas = JSON.parse(fs.readFileSync('./spec-nylas/fixtures/delta-sync/sample.json'))
      @sampleClustered = JSON.parse(fs.readFileSync('./spec-nylas/fixtures/delta-sync/sample-clustered.json'))

    it "should immediately fire the received raw deltas event", ->
      spyOn(Actions, 'longPollReceivedRawDeltas')
      spyOn(NylasAPI, '_clusterDeltas').andReturn({create: {}, modify: {}, destroy: []})
      NylasAPI._handleDeltas(@sampleDeltas)
      expect(Actions.longPollReceivedRawDeltas).toHaveBeenCalled()

    it "should call helper methods for all creates first, then modifications, then destroys", ->
      spyOn(Actions, 'longPollProcessedDeltas')

      handleDeltaDeletionPromises = []
      resolveDeltaDeletionPromises = ->
        fn() for fn in handleDeltaDeletionPromises
        handleDeltaDeletionPromises = []

      spyOn(NylasAPI, '_handleDeltaDeletion').andCallFake ->
        new Promise (resolve, reject) ->
          handleDeltaDeletionPromises.push(resolve)

      handleModelResponsePromises = []
      resolveModelResponsePromises = ->
        fn() for fn in handleModelResponsePromises
        handleModelResponsePromises = []

      spyOn(NylasAPI, '_handleModelResponse').andCallFake ->
        new Promise (resolve, reject) ->
          handleModelResponsePromises.push(resolve)

      NylasAPI._handleDeltas(@sampleDeltas)

      createTypes = Object.keys(@sampleClustered['create'])
      expect(NylasAPI._handleModelResponse.calls.length).toEqual(createTypes.length)
      expect(NylasAPI._handleModelResponse.calls[0].args[0]).toEqual(_.values(@sampleClustered['create'][createTypes[0]]))
      expect(NylasAPI._handleDeltaDeletion.calls.length).toEqual(0)

      NylasAPI._handleModelResponse.reset()
      resolveModelResponsePromises()
      advanceClock()

      modifyTypes = Object.keys(@sampleClustered['modify'])
      expect(NylasAPI._handleModelResponse.calls.length).toEqual(modifyTypes.length)
      expect(NylasAPI._handleModelResponse.calls[0].args[0]).toEqual(_.values(@sampleClustered['modify'][modifyTypes[0]]))
      expect(NylasAPI._handleDeltaDeletion.calls.length).toEqual(0)

      NylasAPI._handleModelResponse.reset()
      resolveModelResponsePromises()
      advanceClock()

      destroyCount = @sampleClustered['destroy'].length
      expect(NylasAPI._handleDeltaDeletion.calls.length).toEqual(destroyCount)
      expect(NylasAPI._handleDeltaDeletion.calls[0].args[0]).toEqual(@sampleClustered['destroy'][0])

      expect(Actions.longPollProcessedDeltas).not.toHaveBeenCalled()

      resolveDeltaDeletionPromises()
      advanceClock()

      expect(Actions.longPollProcessedDeltas).toHaveBeenCalled()

  describe "clusterDeltas", ->
    beforeEach ->
      @sampleDeltas = JSON.parse(fs.readFileSync('./spec-nylas/fixtures/delta-sync/sample.json'))
      @expectedClustered = JSON.parse(fs.readFileSync('./spec-nylas/fixtures/delta-sync/sample-clustered.json'))

    it "should collect create/modify events into a hash by model type", ->
      {create, modify} = NylasAPI._clusterDeltas(@sampleDeltas)
      expect(create).toEqual(@expectedClustered.create)
      expect(modify).toEqual(@expectedClustered.modify)

    it "should collect destroys into an array", ->
      {destroy} = NylasAPI._clusterDeltas(@sampleDeltas)
      expect(destroy).toEqual(@expectedClustered.destroy)

  describe "handleDeltaDeletion", ->
    beforeEach ->
      @thread = new Thread(id: 'idhere')
      @delta =
        "cursor": "bb95ddzqtr2gpmvgrng73t6ih",
        "object": "thread",
        "event": "delete",
        "id": @thread.id,
        "timestamp": "2015-08-26T17:36:45.297Z"

    it "should resolve if the object cannot be found", ->
      spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
        return Promise.resolve(null)
      spyOn(DatabaseStore, 'unpersistModel')
      waitsForPromise =>
        NylasAPI._handleDeltaDeletion(@delta)
      runs =>
        expect(DatabaseStore.find).toHaveBeenCalledWith(Thread, 'idhere')
        expect(DatabaseStore.unpersistModel).not.toHaveBeenCalled()

    it "should call unpersistModel if the object exists", ->
      spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
        return Promise.resolve(@thread)
      spyOn(DatabaseStore, 'unpersistModel')
      waitsForPromise =>
        NylasAPI._handleDeltaDeletion(@delta)
      runs =>
        expect(DatabaseStore.find).toHaveBeenCalledWith(Thread, 'idhere')
        expect(DatabaseStore.unpersistModel).toHaveBeenCalledWith(@thread)

  # These specs are on hold because this function is changing very soon

  xdescribe "handleModelResponse", ->
    it "should reject if no JSON is provided", ->
    it "should resolve if an empty JSON array is provided", ->

    describe "if JSON contains the same object more than once", ->
      it "should warn", ->
      it "should omit duplicates", ->

    describe "if JSON contains objects which are of unknown types", ->
      it "should warn and resolve", ->

    describe "when the object type is `thread`", ->
      it "should check that models are acceptable", ->

    describe "when the object type is `draft`", ->
      it "should check that models are acceptable", ->

    it "should call persistModels to save all of the received objects", ->

    it "should resolve with the objects", ->
