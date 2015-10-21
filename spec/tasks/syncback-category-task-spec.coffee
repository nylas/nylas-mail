SyncbackCategoryTask = require "../../src/flux/tasks/syncback-category-task"
NylasAPI = require "../../src/flux/nylas-api"
{Label, Folder, DatabaseStore} = require "nylas-exports"

describe "SyncbackCategoryTask", ->
  describe "performRemote", ->
    pathOf = (fn) ->
      fn.calls[0].args[0].path

    accountIdOf = (fn) ->
      fn.calls[0].args[0].accountId

    nameOf = (fn) ->
      fn.calls[0].args[0].body.display_name

    makeTask = (CategoryClass) ->
      category = new CategoryClass
        displayName: "important emails"
        accountId: "account 123"
        clientId: "local-444"
      new SyncbackCategoryTask
        category: category

    beforeEach ->
      spyOn(NylasAPI, "makeRequest").andCallFake ->
        Promise.resolve(id: "server-444")
      spyOn(DatabaseStore, "persistModel")

    it "sends API req to /labels if user uses labels", ->
      task = makeTask(Label)
      task.performRemote({})
      expect(pathOf(NylasAPI.makeRequest)).toBe "/labels"

    it "sends API req to /folders if user uses folders", ->
      task = makeTask(Folder)
      task.performRemote({})
      expect(pathOf(NylasAPI.makeRequest)).toBe "/folders"

    it "sends the account id", ->
      task = makeTask(Label)
      task.performRemote({})
      expect(accountIdOf(NylasAPI.makeRequest)).toBe "account 123"

    it "sends the display name in the body", ->
      task = makeTask(Label)
      task.performRemote({})
      expect(nameOf(NylasAPI.makeRequest)).toBe "important emails"

    it "adds server id to the category, then saves the category", ->
      waitsForPromise ->
        task = makeTask(Label)
        task.performRemote({})
        .then ->
          expect(DatabaseStore.persistModel).toHaveBeenCalled()
          model = DatabaseStore.persistModel.calls[0].args[0]
          expect(model.clientId).toBe "local-444"
          expect(model.serverId).toBe "server-444"
