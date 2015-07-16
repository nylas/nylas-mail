_ = require 'underscore'
Label = require '../../src/flux/models/label'
Thread = require '../../src/flux/models/thread'
Message = require '../../src/flux/models/message'
Actions = require '../../src/flux/actions'
NylasAPI = require '../../src/flux/nylas-api'
DatabaseStore = require '../../src/flux/stores/database-store'
ChangeLabelsTask = require '../../src/flux/tasks/change-labels-task'

{APIError} = require '../../src/flux/errors'
{Utils} = require '../../src/flux/models/utils'

testLabels = null
testThread = null
testMessage = null

describe "ChangeLabelsTask", ->
  beforeEach ->
    spyOn(DatabaseStore, 'persistModel').andCallFake -> Promise.resolve()
    spyOn(DatabaseStore, 'persistModels').andCallFake -> Promise.resolve()
    spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
      if klass is Thread
        Promise.resolve(testThread)
      else if klass is Message
        Promise.resolve(testMessage)
      else if klass is Label
        Promise.resolve(testLabels[id])
      else
        throw new Error("Not stubbed!")

    spyOn(DatabaseStore, 'findAll').andCallFake (klass, finder) =>
      if klass is Message
        Promise.resolve([testMessage])
      else
        throw new Error("Not stubbed!")

  describe "shouldWaitForTask", ->
    it "should return true if another, older ChangeLabelsTask involves the same threads", ->
      a = new ChangeLabelsTask(threadIds: ['t1', 't2', 't3'])
      a.creationDate = new Date(1000)
      b = new ChangeLabelsTask(threadIds: ['t3', 't4', 't7'])
      b.creationDate = new Date(2000)
      c = new ChangeLabelsTask(threadIds: ['t0', 't7'])
      c.creationDate = new Date(3000)
      expect(a.shouldWaitForTask(b)).toEqual(false)
      expect(a.shouldWaitForTask(c)).toEqual(false)
      expect(b.shouldWaitForTask(a)).toEqual(true)
      expect(c.shouldWaitForTask(a)).toEqual(false)
      expect(c.shouldWaitForTask(b)).toEqual(true)

  describe "performLocal", ->
    beforeEach ->

      testLabels =
        "l1": new Label({name: 'inbox', id: 'l1', displayName: "INBOX"}),
        "l2": new Label({name: 'drafts', id: 'l2', displayName: "MyDrafts"})
        "l3": new Label({name: null, id: 'l3', displayName: "My Label"})

      testThread = new Thread
        id: 'thread-id'
        labels: _.values(testLabels)

      testMessage = new Message
        id: 'message-id'
        labels: _.values(testLabels)

    it "should throw an exception if task has not been given a thread", ->
      badTasks = [
        new ChangeLabelsTask(),
        new ChangeLabelsTask(threadIds: [123]),
        new ChangeLabelsTask(threadIds: [123], messageIds: ["foo"]),
        new ChangeLabelsTask(threadIds: "Thread"),
      ]
      goodTasks = [
        new ChangeLabelsTask(
          labelsToAdd: ['l2']
          labelsToRemove: ['l1']
          threadIds: [testThread.id]
        )
        new ChangeLabelsTask(
          labelsToAdd: ['l2']
          labelsToRemove: []
          messageIds: [testMessage.id]
        )
      ]
      caught = []
      succeeded = []

      runs ->
        [].concat(badTasks, goodTasks).forEach (task) ->
          task.performLocal()
          .then -> succeeded.push(task)
          .catch (err) -> caught.push(task)
      waitsFor ->
        succeeded.length + caught.length == 6
      runs ->
        expect(caught.length).toEqual(badTasks.length)
        expect(succeeded.length).toEqual(goodTasks.length)

    it 'adds labels to a Thread', ->

    it 'adds labels to a Message', ->

    it 'removes labels from a Thread', ->

    it 'removes labels from a Message', ->
