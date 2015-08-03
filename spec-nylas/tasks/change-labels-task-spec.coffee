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

testLabels = {}
testThreads = {}
testMessages = {}

describe "ChangeLabelsTask", ->
  beforeEach ->
    spyOn(DatabaseStore, 'persistModel').andCallFake -> Promise.resolve()
    spyOn(DatabaseStore, 'persistModels').andCallFake -> Promise.resolve()
    spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
      if klass is Thread
        Promise.resolve(testThreads[id])
      else if klass is Message
        Promise.resolve(testMessages[id])
      else if klass is Label
        Promise.resolve(testLabels[id])
      else
        throw new Error("Not stubbed!")

    spyOn(DatabaseStore, 'findAll').andCallFake (klass, finder) =>
      if klass is Message
        Promise.resolve(_.values(testMessages))
      else if klass is Thread
        Promise.resolve(_.values(testThreads))
      else if klass is Label
        Promise.resolve(_.values(testLabels))
      else
        throw new Error("Not stubbed!")

    testLabels = @testLabels =
      "l1": new Label({name: 'inbox', id: 'l1', displayName: "INBOX"}),
      "l2": new Label({name: 'drafts', id: 'l2', displayName: "MyDrafts"})
      "l3": new Label({name: null, id: 'l3', displayName: "My Label"})

    testThreads = @testThreads =
      't1': new Thread(id: 't1', labels: [@testLabels['l1']])
      't2': new Thread(id: 't2', labels: _.values(@testLabels))
      't3': new Thread(id: 't3', labels: [@testLabels['l2'], @testLabels['l3']])

    testMessages = @testMessages =
      'm1': new Message(id: 'm1', labels: [@testLabels['l1']])
      'm2': new Message(id: 'm2', labels: _.values(@testLabels))
      'm3': new Message(id: 'm3', labels: [@testLabels['l2'], @testLabels['l3']])

    @basicThreadTask = new ChangeLabelsTask
      labelsToAdd: ["l1", "l2"]
      labelsToRemove: ["l3"]
      threadIds: ['t1']

    @basicMessageTask = new ChangeLabelsTask
      labelsToAdd: ["l1", "l2"]
      labelsToRemove: ["l3"]
      messageIds: ['m1']

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
          threadIds: ['t1']
        )
        new ChangeLabelsTask(
          labelsToAdd: ['l2']
          labelsToRemove: []
          messageIds: ['m1']
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

    it 'finds all of the labels to add by id', ->
      waitsForPromise =>
        @basicThreadTask.collectCategories().then (categories) =>
          expect(categories.labelsToAdd).toEqual [@testLabels['l1'], @testLabels['l2']]
          expect(categories.labelsToRemove).toEqual [@testLabels['l3']]

    it 'finds all of the labels to add by object', ->
      task = new ChangeLabelsTask
        labelsToAdd: [@testLabels['l1'], @testLabels['l2']]
        labelsToRemove: []
        threadIds: ['t1']

      waitsForPromise =>
        task.collectCategories().then (categories) =>
          expect(categories.labelsToAdd).toEqual [@testLabels['l1'], @testLabels['l2']]
          expect(categories.labelsToRemove).toEqual []

    it 'increments optimistic changes', ->
      spyOn(@basicThreadTask, "localUpdateThread").andReturn Promise.resolve()
      spyOn(NylasAPI, "incrementOptimisticChangeCount")
      @basicThreadTask.performLocal().then ->
        expect(NylasAPI.incrementOptimisticChangeCount)
          .toHaveBeenCalledWith(Thread, 't1')

    it 'decrements optimistic changes if reverting', ->
      spyOn(@basicThreadTask, "localUpdateThread").andReturn Promise.resolve()
      spyOn(NylasAPI, "decrementOptimisticChangeCount")
      @basicThreadTask.performLocal(reverting: true).then ->
        expect(NylasAPI.decrementOptimisticChangeCount)
          .toHaveBeenCalledWith(Thread, 't1')

    describe 'when creating a _newLabelSet', ->
      it 'properly adds labels', ->
        t1 = @testThreads['t1']
        toAdd = [@testLabels['l1'], @testLabels['l2']]
        out = @basicThreadTask._newLabelSet(t1, labelsToAdd: toAdd)
        expect(out).toEqual toAdd

      it 'properly removes labels', ->
        t3 = @testThreads['t3']
        toRemove = [@testLabels['l1'], @testLabels['l2']]
        out = @basicThreadTask._newLabelSet(t3, labelsToRemove: toRemove)
        expect(out).toEqual [@testLabels['l3']]

      it 'properly adds and removes labels', ->
        t1 = @testThreads['t1']
        toAdd = [@testLabels['l1'], @testLabels['l2']]
        toRemove = [@testLabels['l2'], @testLabels['l3']]
        out = @basicThreadTask._newLabelSet(t1, labelsToAdd: toAdd, labelsToRemove: toRemove)
        expect(out).toEqual [@testLabels['l1']]

    it 'updates a thread with the new labels', ->
      expectedLabels = [@testLabels['l1'], @testLabels['l2']]
      @basicThreadTask.performLocal().then ->
        thread = DatabaseStore.persistModel.calls[0].args[0]
        expect(thread.labels).toEqual expectedLabels

    it "updates a thread's messages with the new labels", ->
      # Our stub of DatabaseStore.findAll ignores the scoping parameter.
      # We simply return all messages.

      expectedLabels = [@testLabels['l1'], @testLabels['l2']]
      @basicThreadTask.performLocal().then ->
        messages = DatabaseStore.persistModels.calls[0].args[0]
        expect(messages.length).toBe 3
        for message in messages
          expect(message.labels).toEqual expectedLabels

    it "doesn't botter updating the message if it already has the correct labels", ->
      @testMessages['m4'] =
        new Message(id: 'm4', labels: [@testLabels['l1'], @testLabels['l2']])
      @testMessages['m5'] =
        new Message(id: 'm5', labels: [])

      expectedLabels = [@testLabels['l1'], @testLabels['l2']]
      @basicThreadTask.performLocal().then =>
        messages = DatabaseStore.persistModels.calls[0].args[0]
        expect(messages.length).toBe 4
        for message in messages
          expect(message.labels).toEqual expectedLabels
        expect(@testMessages['m4'] not in messages).toBe true

    it 'updates a message with the new labels on a message task', ->
      expectedLabels = [@testLabels['l1'], @testLabels['l2']]
      @basicMessageTask.performLocal().then ->
        thread = DatabaseStore.persistModel.calls[0].args[0]
        expect(thread.labels).toEqual expectedLabels

    it 'saves the new label set to an instance variable on the task so performRemote can access it later', ->
      expectedLabels = [@testLabels['l1'], @testLabels['l2']]
      @basicThreadTask.performLocal().then =>
        expect(@basicThreadTask._newLabels['t1']).toEqual expectedLabels

  describe 'performRemote', ->
    beforeEach ->
      spyOn(NylasAPI, "makeRequest").andCallFake (options) ->
        options.beforeProcessing?(options.body)
        return Promise.resolve()

      @multiThreadTask = new ChangeLabelsTask
        labelsToAdd: ["l1", "l2"]
        labelsToRemove: ["l3"]
        threadIds: ['t1', 't2']

      @multiMessageTask = new ChangeLabelsTask
        labelsToAdd: ["l1", "l2"]
        labelsToRemove: ["l3"]
        messageIds: ['m1', 'm2']

      expectedLabels = [@testLabels['l1'], @testLabels['l2']]
      @multiThreadTask._newLabels['t1'] = expectedLabels
      @multiThreadTask._newLabels['t2'] = expectedLabels
      @multiMessageTask._newLabels['m1'] = expectedLabels
      @multiMessageTask._newLabels['m2'] = expectedLabels

    it 'makes a new request object for each object', ->
      @multiThreadTask.performRemote().then ->
        expect(NylasAPI.makeRequest.calls.length).toBe 2

    it 'decrements the optimistic change count on each request', ->
      spyOn(NylasAPI, "decrementOptimisticChangeCount")
      @multiThreadTask.performRemote().then ->
        klass = NylasAPI.decrementOptimisticChangeCount.calls[0].args[0]
        expect(NylasAPI.decrementOptimisticChangeCount.calls.length).toBe 2
        expect(klass).toBe Thread

    it 'decrements the optimistic change for messages too', ->
      spyOn(NylasAPI, "decrementOptimisticChangeCount")
      @multiMessageTask.performRemote().then ->
        klass = NylasAPI.decrementOptimisticChangeCount.calls[0].args[0]
        expect(NylasAPI.decrementOptimisticChangeCount.calls.length).toBe 2
        expect(klass).toBe Message

    it 'properly passes the label IDs to the body', ->
      @multiThreadTask.performRemote().then ->
        opts = NylasAPI.makeRequest.calls[0].args[0]
        expect(opts.body).toEqual labels: ['l1', 'l2']

    it 'gets the correct endpoint for the thread tasks', ->
      @multiThreadTask.performRemote().then ->
        opts = NylasAPI.makeRequest.calls[0].args[0]
        expect(opts.path).toEqual "/n/nsid/threads/t1"

    it 'gets the correct endpoint for the message tasks', ->
      @multiMessageTask.performRemote().then ->
        opts = NylasAPI.makeRequest.calls[0].args[0]
        expect(opts.path).toEqual "/n/nsid/messages/m1"
