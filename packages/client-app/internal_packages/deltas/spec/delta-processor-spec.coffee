_ = require 'underscore'
fs = require 'fs'
path = require 'path'
{NylasAPIHelpers,
 Thread,
 DatabaseTransaction,
 Actions,
 Message,
 Thread} = require 'nylas-exports'

DeltaProcessor = require('../lib/delta-processor').default

fixturesPath = path.resolve(__dirname, 'fixtures')

describe "DeltaProcessor", ->

  describe "handleDeltas", ->
    beforeEach ->
      @sampleDeltas = JSON.parse(fs.readFileSync("#{fixturesPath}/sample.json"))
      @sampleClustered = JSON.parse(fs.readFileSync("#{fixturesPath}/sample-clustered.json"))

    it "should immediately fire the received raw deltas event", ->
      spyOn(Actions, 'longPollReceivedRawDeltas')
      spyOn(DeltaProcessor, '_clusterDeltas').andReturn({create: {}, modify: {}, destroy: []})
      waitsForPromise ->
        DeltaProcessor.process(@sampleDeltas, {source: 'n1Cloud'})
      runs ->
        expect(Actions.longPollReceivedRawDeltas).toHaveBeenCalled()

    xit "should call helper methods for all creates first, then modifications, then destroys", ->
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
        "objectId": @thread.id,
        "timestamp": "2015-08-26T17:36:45.297Z"

      spyOn(DatabaseTransaction.prototype, 'unpersistModel')

    it "should resolve if the object cannot be found", ->
      spyOn(DatabaseTransaction.prototype, 'find').andCallFake (klass, id) =>
        return Promise.resolve(null)
      waitsForPromise =>
        DeltaProcessor._handleDestroyDelta(@delta)
      runs =>
        expect(DatabaseTransaction.prototype.find).toHaveBeenCalledWith(Thread, 'idhere')
        expect(DatabaseTransaction.prototype.unpersistModel).not.toHaveBeenCalled()

    it "should call unpersistModel if the object exists", ->
      spyOn(DatabaseTransaction.prototype, 'find').andCallFake (klass, id) =>
        return Promise.resolve(@thread)
      waitsForPromise =>
        DeltaProcessor._handleDestroyDelta(@delta)
      runs =>
        expect(DatabaseTransaction.prototype.find).toHaveBeenCalledWith(Thread, 'idhere')
        expect(DatabaseTransaction.prototype.unpersistModel).toHaveBeenCalledWith(@thread)

  describe "handleModelResponse", ->
    # SEE spec/nylas-api-spec.coffee

  describe "receives metadata deltas", ->
    beforeEach ->
      @stubDB = {}
      spyOn(DatabaseTransaction.prototype, 'find').andCallFake (klass, id) =>
        return @stubDB[id]
      spyOn(DatabaseTransaction.prototype, 'findAll').andCallFake (klass, where) =>
        ids = where.id
        models = []
        ids.forEach (id) =>
          model = @stubDB[id]
          if model
            models.push(model)
        return models
      spyOn(DatabaseTransaction.prototype, 'persistModels').andCallFake (models) =>
        models.forEach (model) =>
          @stubDB[model.id] = model
        return Promise.resolve()

      @messageMetadataDelta =
        id: 519,
        event: "create",
        object: "metadata",
        objectId: 8876,
        changedFields: ["version", "object"],
        attributes:
          id: 8876,
          value: {link_clicks: 1},
          object: "metadata",
          version: 2,
          plugin_id: "link-tracking",
          object_id: '2887',
          object_type: "message",
          account_id: 2

      @threadMetadataDelta =
        id: 392,
        event: "create",
        object: "metadata",
        objectId: 3845,
        changedFields: ["version", "object"],
        attributes:
          id: 3845,
          value: {shouldNotify: true},
          object: "metadata",
          version: 2,
          plugin_id: "send-reminders",
          object_id: 't:3984',
          object_type: "thread"
          account_id: 2,

    it "saves metadata to existing Messages", ->
      message = new Message({serverId: @messageMetadataDelta.attributes.object_id})
      @stubDB[message.id] = message
      waitsForPromise =>
        DeltaProcessor.process([@messageMetadataDelta])
      runs ->
        message = @stubDB[message.id] # refresh reference
        expect(message.pluginMetadata.length).toEqual(1)
        expect(message.metadataForPluginId('link-tracking')).toEqual({link_clicks: 1})

    it "saves metadata to existing Threads", ->
      thread = new Thread({serverId: @threadMetadataDelta.attributes.object_id})
      @stubDB[thread.id] = thread
      waitsForPromise =>
        DeltaProcessor.process([@threadMetadataDelta])
      runs ->
        thread = @stubDB[thread.id] # refresh reference
        expect(thread.pluginMetadata.length).toEqual(1)
        expect(thread.metadataForPluginId('send-reminders')).toEqual({shouldNotify: true})

    it "knows how to reconcile different thread ids", ->
      thread = new Thread({serverId: 't:1948'})
      @stubDB[thread.id] = thread
      message = new Message({
        serverId: @threadMetadataDelta.attributes.object_id.substring(2),
        threadId: thread.id
      })
      @stubDB[message.id] = message
      waitsForPromise =>
        DeltaProcessor.process([@threadMetadataDelta])
      runs ->
        thread = @stubDB[thread.id] # refresh reference
        expect(thread.pluginMetadata.length).toEqual(1)
        expect(thread.metadataForPluginId('send-reminders')).toEqual({shouldNotify: true})

    it "creates ghost Messages if necessary", ->
      waitsForPromise =>
        DeltaProcessor.process([@messageMetadataDelta])
      runs ->
        message = @stubDB[@messageMetadataDelta.attributes.object_id]
        expect(message).toBeDefined()
        expect(message.pluginMetadata.length).toEqual(1)
        expect(message.metadataForPluginId('link-tracking')).toEqual({link_clicks: 1})

    it "creates ghost Threads if necessary", ->
      waitsForPromise =>
        DeltaProcessor.process([@threadMetadataDelta])
      runs ->
        thread = @stubDB[@threadMetadataDelta.attributes.object_id]
        expect(thread.pluginMetadata.length).toEqual(1)
        expect(thread.metadataForPluginId('send-reminders')).toEqual({shouldNotify: true})
