{NylasAPI,
 Category,
 AccountStore,
 DatabaseStore,
 SyncbackCategoryTask,
 DatabaseTransaction} = require "nylas-exports"

describe "SyncbackCategoryTask", ->
  describe "performRemote", ->
    pathOf = (fn) ->
      fn.calls[0].args[0].path

    accountIdOf = (fn) ->
      fn.calls[0].args[0].accountId

    nameOf = (fn) ->
      fn.calls[0].args[0].body.display_name

    makeAccount = ({usesFolders, usesLabels} = {}) ->
      spyOn(AccountStore, "accountForId").andReturn {
        usesFolders: -> usesFolders
        usesLabels: -> usesLabels
      }

    makeTask = ->
      category = new Category
        displayName: "important emails"
        accountId: "account 123"
        clientId: "local-444"
      new SyncbackCategoryTask
        category: category

    beforeEach ->
      spyOn(NylasAPI, "makeRequest").andCallFake ->
        Promise.resolve(id: "server-444")
      spyOn(DatabaseTransaction.prototype, "persistModel")

    it "sends API req to /labels if the account uses labels", ->
      makeAccount(usesLabels: true)
      task = makeTask()
      task.performRemote({})
      expect(pathOf(NylasAPI.makeRequest)).toBe "/labels"

    it "sends API req to /folders if the account uses folders", ->
      makeAccount(usesFolders: true)
      task = makeTask()
      task.performRemote({})
      expect(pathOf(NylasAPI.makeRequest)).toBe "/folders"

    it "sends the account id", ->
      makeAccount()
      task = makeTask()
      task.performRemote({})
      expect(accountIdOf(NylasAPI.makeRequest)).toBe "account 123"

    it "sends the display name in the body", ->
      makeAccount()
      task = makeTask()
      task.performRemote({})
      expect(nameOf(NylasAPI.makeRequest)).toBe "important emails"

    it "adds server id to the category, then saves the category", ->
      makeAccount()
      waitsForPromise ->
        task = makeTask()
        task.performRemote({})
        .then ->
          expect(DatabaseTransaction.prototype.persistModel).toHaveBeenCalled()
          model = DatabaseTransaction.prototype.persistModel.calls[0].args[0]
          expect(model.clientId).toBe "local-444"
          expect(model.serverId).toBe "server-444"
