Actions = require '../../src/flux/actions'
AddRemoveTagsTask = require '../../src/flux/tasks/add-remove-tags'
MarkThreadReadTask = require '../../src/flux/tasks/mark-thread-read'
DatabaseStore = require '../../src/flux/stores/database-store'
Thread = require '../../src/flux/models/thread'
_ = require 'underscore-plus'

describe "MarkThreadReadTask", ->
  beforeEach ->
    @thread = new Thread
      id: '1233123AEDF1'
      namespaceId: 'A12ADE'
      subject: 'New Thread'
      unread: true
      to:
        name: 'Dummy'
        email: 'dummy@inboxapp.com'
    @task = new MarkThreadReadTask(@thread)

  describe "performLocal", ->
    it "should call through to its superclass", ->
      spyOn(AddRemoveTagsTask.prototype, 'performLocal').andCallFake -> Promise.resolve()
      @task.performLocal()
      expect(AddRemoveTagsTask.prototype.performLocal).toHaveBeenCalled()

  describe "performRemote", ->
    it "should call through to its superclass", ->
      spyOn(AddRemoveTagsTask.prototype, 'performRemote')
      @task.performRemote()
      expect(AddRemoveTagsTask.prototype.performRemote).toHaveBeenCalled()
