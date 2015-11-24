DestroyCategoryTask = require "../../src/flux/tasks/destroy-category-task"
NylasAPI = require "../../src/flux/nylas-api"
Task = require '../../src/flux/tasks/task'
{APIError} = require '../../src/flux/errors'
{Label, Folder, DatabaseStore} = require "nylas-exports"

describe "DestroyCategoryTask", ->
  pathOf = (fn) ->
    fn.calls[0].args[0].path

  methodOf = (fn) ->
    fn.calls[0].args[0].method

  accountIdOf = (fn) ->
    fn.calls[0].args[0].accountId

  nameOf = (fn) ->
    fn.calls[0].args[0].body.display_name

  makeTask = (CategoryClass) ->
    category = new CategoryClass
      displayName: "important emails"
      accountId: "account 123"
      serverId: "server-444"
    new DestroyCategoryTask
      category: category

  describe "performLocal", ->
    beforeEach ->
      spyOn(DatabaseStore, 'persistModel')

    it "sets an is deleted flag and persists the category", ->
      task = makeTask(Folder)
      task.performLocal()

      expect(DatabaseStore.persistModel).toHaveBeenCalled()
      model = DatabaseStore.persistModel.calls[0].args[0]
      expect(model.serverId).toEqual "server-444"
      expect(model.isDeleted).toBe true

  describe "performRemote", ->
    it "throws error when no category present", ->
      waitsForPromise ->
        task = makeTask(Label)
        task.category = null
        task.performRemote()
        .then ->
          throw new Error('The promise should reject')
        .catch Error, (err) ->
          expect(err).toBeDefined()

    it "throws error when category does not have a serverId", ->
      waitsForPromise ->
        task = makeTask(Label)
        task.category.serverId = undefined
        task.performRemote()
        .then ->
          throw new Error('The promise should reject')
        .catch Error, (err) ->
          expect(err).toBeDefined()

    describe "when request succeeds", ->
      beforeEach ->
        spyOn(NylasAPI, "makeRequest").andCallFake -> Promise.resolve("null")

      it "sends API req to /labels if user uses labels", ->
        task = makeTask(Label)
        task.performRemote()
        expect(pathOf(NylasAPI.makeRequest)).toBe "/labels/server-444"

      it "sends API req to /folders if user uses folders", ->
        task = makeTask(Folder)
        task.performRemote()
        expect(pathOf(NylasAPI.makeRequest)).toBe "/folders/server-444"

      it "sends DELETE request", ->
        task = makeTask(Folder)
        task.performRemote()
        expect(methodOf(NylasAPI.makeRequest)).toBe "DELETE"

      it "sends the account id", ->
        task = makeTask(Label)
        task.performRemote()
        expect(accountIdOf(NylasAPI.makeRequest)).toBe "account 123"

    describe "when request fails", ->
      beforeEach ->
        spyOn(NylasEnv, 'emitError')
        spyOn(DatabaseStore, 'persistModel').andCallFake ->
          Promise.resolve()
        spyOn(NylasAPI, 'makeRequest').andCallFake ->
          Promise.reject(new APIError({statusCode: 403}))

      it "updates the isDeleted flag for the category and notifies error", ->
        waitsForPromise ->
          task = makeTask(Folder)
          spyOn(task, "_notifyUserOfError")

          task.performRemote().then (status) ->
            expect(status).toEqual Task.Status.Failed
            expect(task._notifyUserOfError).toHaveBeenCalled()
            expect(NylasEnv.emitError).toHaveBeenCalled()
            expect(DatabaseStore.persistModel).toHaveBeenCalled()
            model = DatabaseStore.persistModel.calls[0].args[0]
            expect(model.serverId).toEqual "server-444"
            expect(model.isDeleted).toBe false
