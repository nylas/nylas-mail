NylasAPI = require '../../src/flux/nylas-api'
Actions = require '../../src/flux/actions'
MarkMessageReadTask = require '../../src/flux/tasks/mark-message-read'
DatabaseStore = require '../../src/flux/stores/database-store'
Message = require '../../src/flux/models/message'
_ = require 'underscore'

describe "MarkMessageReadTask", ->
  beforeEach ->
    @message = new Message
      id: '1233123AEDF1'
      namespaceId: 'A12ADE'
      subject: 'New Message'
      unread: true
      to:
        name: 'Dummy'
        email: 'dummy@nylas.com'
    @task = new MarkMessageReadTask(@message)

  describe "_rollbackLocal", ->
    beforeEach ->
      spyOn(DatabaseStore, 'persistModel').andCallFake -> Promise.resolve()

    it "should not mark the message as unread if it was not unread initially", ->
      message = new Message
        id: '1233123AEDF1'
        namespaceId: 'A12ADE'
        subject: 'New Message'
        unread: false
        to:
          name: 'Dummy'
          email: 'dummy@nylas.com'
      @task = new MarkMessageReadTask(message)
      @task.performLocal()
      @task._rollbackLocal()
      expect(message.unread).toBe(false)

    it "should mark the message as unread", ->
      @task.performLocal()
      @task._rollbackLocal()
      expect(@message.unread).toBe(true)

    it "should trigger an action to persist the change", ->
      @task.performLocal()
      @task._rollbackLocal()
      expect(DatabaseStore.persistModel).toHaveBeenCalled()

  describe "performLocal", ->
    it "should mark the message as read", ->
      @task.performLocal()
      expect(@message.unread).toBe(false)

    it "should trigger an action to persist the change", ->
      spyOn(DatabaseStore, 'persistModel').andCallFake -> Promise.resolve()
      @task.performLocal()
      expect(DatabaseStore.persistModel).toHaveBeenCalled()

  describe "performRemote", ->
    it "should make the PUT request to the message endpoint", ->
      spyOn(NylasAPI, 'makeRequest')
      @task.performRemote()
      options = NylasAPI.makeRequest.mostRecentCall.args[0]
      expect(options.path).toBe("/n/#{@message.namespaceId}/messages/#{@message.id}")
      expect(options.method).toBe('PUT')
      expect(options.body.unread).toBe(false)
