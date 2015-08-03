Task = require '../../src/flux/tasks/task'
Model = require '../../src/flux/models/model'
NylasAPI = require '../../src/flux/nylas-api'
Attributes = require '../../src/flux/attributes'
DatabaseStore = require '../../src/flux/stores/database-store'
UpdateNylasObjectsTask = require '../../src/flux/tasks/update-nylas-objects-task'

{APIError} = require '../../src/flux/errors'

class TestModel extends Model
  @attributes:
    'name': Attributes.String
      modelKey: 'name'
    'unread': Attributes.Boolean
      modelKey: 'unread'
    'starred': Attributes.Boolean
      modelKey: 'starred'

describe 'UpdateNylasObjectsTask', ->

  beforeEach ->
    @origValues =
      "id-1":
        id: "id-1"
        name: "Evan"
        unread: true
        starred: false
      "id-2":
        id: "id-2"
        name: "Ben"
        unread: true
        starred: false
      "id-3":
        id: "id-3"
        name: "Michael"
        unread: true
        starred: false

    @newValues =
      unread: false
      starred: true

    @objects = [
      new TestModel(@origValues["id-1"])
      new TestModel(@origValues["id-2"])
      new TestModel(@origValues["id-3"])
    ]
    @objects[0].id = "id-1"
    @objects[1].id = "id-2"
    @objects[2].id = "id-3"

    spyOn(DatabaseStore, 'persistModels').andCallFake -> Promise.resolve()

    @task = new UpdateNylasObjectsTask(@objects, @newValues)

  describe 'when performing local', ->
    it "saves the updates to the db", ->
      waitsForPromise =>
        @task.performLocal().then =>
          expect(DatabaseStore.persistModels).toHaveBeenCalledWith(@objects)
          objects = DatabaseStore.persistModels.calls[0].args[0]
          for obj in objects
            expect(obj.unread).toBe @newValues.unread
            expect(obj.starred).toBe @newValues.starred

  describe 'when performing remote', ->
    it "persists data to the api", ->
      spyOn(NylasAPI, 'makeRequest').andCallFake -> Promise.resolve()
      waitsForPromise =>
        @task.performRemote().then (status) =>
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          for call, i in NylasAPI.makeRequest.calls
            opts = call.args[0]
            expect(opts.path).toBe "/n/nsid/testmodels/#{@objects[i].id}"
          expect(status).toBe Task.Status.Finished

    it "reverts if there's an error", ->
      spyOn(NylasAPI, 'makeRequest').andCallFake ->
        Promise.reject(new APIError(statusCode: 404))
      waitsForPromise =>
        @task.performRemote().then =>
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          origIds = @objects.map (obj) -> obj.id
          calledIds = DatabaseStore.persistModels.calls[0].args[0].map (o) -> o.id
          expect(origIds).toEqual calledIds
          objects = DatabaseStore.persistModels.calls[0].args[0]
          for obj in objects
            expect(obj.unread).toBe true
            expect(obj.starred).toBe false

    it "retries if there are retryable errors", ->
      spyOn(NylasAPI, 'makeRequest').andCallFake ->
        Promise.reject(new APIError(statusCode: 0))
      spyOn(@task, "performLocal")
      waitsForPromise =>
        @task.performRemote().then (status) =>
          expect(NylasAPI.makeRequest).toHaveBeenCalled()
          for call, i in NylasAPI.makeRequest.calls
            opts = call.args[0]
            expect(opts.path).toBe "/n/nsid/testmodels/#{@objects[i].id}"
          expect(status).toBe Task.Status.Retry
          expect(@task.performLocal).not.toHaveBeenCalled()

  describe 'description', ->
    it 'should default to "Updated `count` `type``"', ->
      objects = [
        new TestModel(@origValues["id-1"])
        new TestModel(@origValues["id-2"])
        new TestModel(@origValues["id-3"])
      ]
      task = new UpdateNylasObjectsTask(objects, {bla: true})
      expect(task.description()).toEqual("Updated 3 testmodels")
      task = new UpdateNylasObjectsTask([objects[0]], {bla: true})
      expect(task.description()).toEqual("Updated 1 testmodel")

  describe 'when undoing', ->
    beforeEach ->
      @undoTask = new UpdateNylasObjectsTask(@objects, {}, @origValues)
      @undoTask._isUndoTask = true

    describe 'when performing local', ->
      it "saves the old values to the db", ->
        waitsForPromise =>
          @undoTask.performLocal().then =>
            expect(DatabaseStore.persistModels).toHaveBeenCalledWith(@objects)
            objects = DatabaseStore.persistModels.calls[0].args[0]
            for obj in objects
              expect(obj.unread).toBe true
              expect(obj.starred).toBe false

    describe 'when performing remote', ->
      it "persists the old values to the API", ->
        spyOn(NylasAPI, 'makeRequest').andCallFake -> Promise.resolve()
        waitsForPromise =>
          @undoTask.performRemote().then (status) =>
            expect(NylasAPI.makeRequest).toHaveBeenCalled()
            for call, i in NylasAPI.makeRequest.calls
              opts = call.args[0]
              expect(opts.path).toBe "/n/nsid/testmodels/#{@objects[i].id}"
              expect(opts.body.unread).toBe true
              expect(opts.body.starred).toBe false
            expect(status).toBe Task.Status.Finished
