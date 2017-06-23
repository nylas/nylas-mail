{DestroyCategoryTask,
 NylasAPI,
 NylasAPIRequest,
 Task,
 Category,
 AccountStore,
 APIError,
 Category,
 DatabaseStore,
 DatabaseWriter} = require "nylas-exports"

xdescribe "DestroyCategoryTask", ->
  pathOf = (fn) ->
    fn.calls[0].args[0].path

  methodOf = (fn) ->
    fn.calls[0].args[0].method

  accountIdOf = (fn) ->
    fn.calls[0].args[0].accountId

  nameOf = (fn) ->
    fn.calls[0].args[0].body.displayName

  makeAccount = ({usesFolders, usesLabels} = {}) ->
    spyOn(AccountStore, "accountForId").andReturn {
      usesFolders: -> usesFolders
      usesLabels: -> usesLabels
    }
  makeTask = ->
    category = new Category
      displayName: "important emails"
      accountId: "account 123"
      id: "server-444"
    new DestroyCategoryTask
      category: category

  beforeEach ->
    spyOn(DatabaseWriter.prototype, 'unpersistModel').andCallFake -> Promise.resolve()
    spyOn(DatabaseWriter.prototype, 'persistModel').andCallFake -> Promise.resolve()

  describe "performLocal", ->
    it "sets an `isDeleted` flag and persists the category", ->
      task = makeTask()
      runs =>
        task.performLocal()
      waitsFor =>
        DatabaseWriter.prototype.unpersistModel.callCount > 0
      runs =>
        model = DatabaseWriter.prototype.unpersistModel.calls[0].args[0]
        expect(model.id).toEqual "server-444"

