_ = require 'underscore'
fs = require 'fs'
path = require 'path'
{NylasAPIHelpers,
 Thread,
 DatabaseStore,
 DatabaseTransaction,
 Actions} = require 'nylas-exports'

DeltaProcessor = require('../lib/delta-processor').default

fixturesPath = path.resolve(__dirname, 'fixtures')

xdescribe "DeltaProcessor", ->

  describe "handleDeltas", ->
    beforeEach ->
      @sampleDeltas = JSON.parse(fs.readFileSync("#{fixturesPath}/sample.json"))
      @sampleClustered = JSON.parse(fs.readFileSync("#{fixturesPath}/sample-clustered.json"))

    it "should immediately fire the received raw deltas event", ->
      spyOn(Actions, 'longPollReceivedRawDeltas')
      spyOn(DeltaProcessor, '_clusterDeltas').andReturn({create: {}, modify: {}, destroy: []})
      DeltaProcessor.process(@sampleDeltas)
      expect(Actions.longPollReceivedRawDeltas).toHaveBeenCalled()

    it "should call helper methods for all creates first, then modifications, then destroys", ->
      spyOn(Actions, 'longPollProcessedDeltas')

      handleDeltaDeletionPromises = []
      resolveDeltaDeletionPromises = ->
        fn() for fn in handleDeltaDeletionPromises
        handleDeltaDeletionPromises = []

      spyOn(DeltaProcessor, '_handleDestroyDelta').andCallFake ->
        new Promise (resolve, reject) ->
          handleDeltaDeletionPromises.push(resolve)

      handleModelResponsePromises = []
      resolveModelResponsePromises = ->
        fn() for fn in handleModelResponsePromises
        handleModelResponsePromises = []

      spyOn(NylasAPIHelpers, 'handleModelResponse').andCallFake ->
        new Promise (resolve, reject) ->
          handleModelResponsePromises.push(resolve)

      spyOn(DeltaProcessor, '_clusterDeltas').andReturn(JSON.parse(JSON.stringify(@sampleClustered)))
      DeltaProcessor.process(@sampleDeltas)

      createTypes = Object.keys(@sampleClustered['create'])
      expect(NylasAPIHelpers.handleModelResponse.calls.length).toEqual(createTypes.length)
      expect(NylasAPIHelpers.handleModelResponse.calls[0].args[0]).toEqual(_.values(@sampleClustered['create'][createTypes[0]]))
      expect(DeltaProcessor._handleDestroyDelta.calls.length).toEqual(0)

      NylasAPIHelpers.handleModelResponse.reset()
      resolveModelResponsePromises()
      advanceClock()

      modifyTypes = Object.keys(@sampleClustered['modify'])
      expect(NylasAPIHelpers.handleModelResponse.calls.length).toEqual(modifyTypes.length)
      expect(NylasAPIHelpers.handleModelResponse.calls[0].args[0]).toEqual(_.values(@sampleClustered['modify'][modifyTypes[0]]))
      expect(DeltaProcessor._handleDestroyDelta.calls.length).toEqual(0)

      NylasAPIHelpers.handleModelResponse.reset()
      resolveModelResponsePromises()
      advanceClock()

      destroyCount = @sampleClustered['destroy'].length
      expect(DeltaProcessor._handleDestroyDelta.calls.length).toEqual(destroyCount)
      expect(DeltaProcessor._handleDestroyDelta.calls[0].args[0]).toEqual(@sampleClustered['destroy'][0])

      expect(Actions.longPollProcessedDeltas).not.toHaveBeenCalled()

      resolveDeltaDeletionPromises()
      advanceClock()

      expect(Actions.longPollProcessedDeltas).toHaveBeenCalled()

  describe "clusterDeltas", ->
    beforeEach ->
      @sampleDeltas = JSON.parse(fs.readFileSync("#{fixturesPath}/sample.json"))
      @expectedClustered = JSON.parse(fs.readFileSync("#{fixturesPath}/sample-clustered.json"))

    it "should collect create/modify events into a hash by model type", ->
      {create, modify} = DeltaProcessor._clusterDeltas(@sampleDeltas)
      expect(create).toEqual(@expectedClustered.create)
      expect(modify).toEqual(@expectedClustered.modify)

    it "should collect destroys into an array", ->
      {destroy} = DeltaProcessor._clusterDeltas(@sampleDeltas)
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

      spyOn(DatabaseTransaction.prototype, 'unpersistModel')

    it "should resolve if the object cannot be found", ->
      spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
        return Promise.resolve(null)
      waitsForPromise =>
        DeltaProcessor._handleDestroyDelta(@delta)
      runs =>
        expect(DatabaseStore.find).toHaveBeenCalledWith(Thread, 'idhere')
        expect(DatabaseTransaction.prototype.unpersistModel).not.toHaveBeenCalled()

    it "should call unpersistModel if the object exists", ->
      spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
        return Promise.resolve(@thread)
      waitsForPromise =>
        DeltaProcessor._handleDestroyDelta(@delta)
      runs =>
        expect(DatabaseStore.find).toHaveBeenCalledWith(Thread, 'idhere')
        expect(DatabaseTransaction.prototype.unpersistModel).toHaveBeenCalledWith(@thread)

  describe "handleModelResponse", ->
    # SEE spec/nylas-api-spec.coffee
