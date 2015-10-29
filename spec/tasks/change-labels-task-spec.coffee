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
    # IMPORTANT: These specs do not run the performLocal logic of their superclass!
    # Tests for that logic are in change-mail-task-spec.
    spyOn(ChangeLabelsTask.__super__, 'performLocal').andCallFake =>
      Promise.resolve()

    spyOn(DatabaseStore, 'modelify').andCallFake (klass, items) =>
      Promise.resolve items.map (item) =>
        return testLabels[item] if testLabels[item]
        return testThreads[item] if testThreads[item]
        return testMessages[item] if testMessages[item]
        item

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
      threads: ['t1']

    @basicMessageTask = new ChangeLabelsTask
      labelsToAdd: ["l1", "l2"]
      labelsToRemove: ["l3"]
      messages: ['m1']

  describe "description", ->
    it "should include the name of the added label if it's the only mutation and it was provided as an object", ->
      task = new ChangeLabelsTask(labelsToAdd: ["l1"], labelsToRemove: [], threads: ['t1'])
      expect(task.description()).toEqual("Changed labels on 1 thread")
      task = new ChangeLabelsTask(labelsToAdd: [new Label(id: 'l1', displayName: 'LABEL')], labelsToRemove: [], threads: ['t1'])
      expect(task.description()).toEqual("Added LABEL to 1 thread")
      task = new ChangeLabelsTask(labelsToAdd: [new Label(id: 'l1', displayName: 'LABEL')], labelsToRemove: ['l2'], threads: ['t1'])
      expect(task.description()).toEqual("Changed labels on 1 thread")

    it "should include the name of the removed label if it's the only mutation and it was provided as an object", ->
      task = new ChangeLabelsTask(labelsToAdd: [], labelsToRemove: ["l1"], threads: ['t1'])
      expect(task.description()).toEqual("Changed labels on 1 thread")
      task = new ChangeLabelsTask(labelsToAdd: [], labelsToRemove: [new Label(id: 'l1', displayName: 'LABEL')], threads: ['t1'])
      expect(task.description()).toEqual("Removed LABEL from 1 thread")
      task = new ChangeLabelsTask(labelsToAdd: ['l2'], labelsToRemove: [new Label(id: 'l1', displayName: 'LABEL')], threads: ['t1'])
      expect(task.description()).toEqual("Changed labels on 1 thread")

    it "should pluralize properly", ->
      task = new ChangeLabelsTask(labelsToAdd: ["l2"], labelsToRemove: ["l1"], threads: ['t1', 't2', 't3'])
      expect(task.description()).toEqual("Changed labels on 3 threads")

  describe "performLocal", ->
    it "should throw an exception if task has not been given a label, or messages and threads", ->
      badTasks = [
        new ChangeLabelsTask(),
        new ChangeLabelsTask(threads: [123]),
        new ChangeLabelsTask(threads: [123], messages: ["foo"]),
        new ChangeLabelsTask(threads: "Thread"),
      ]
      goodTasks = [
        new ChangeLabelsTask(
          labelsToAdd: ['l2']
          labelsToRemove: ['l1']
          threads: ['t1']
        )
        new ChangeLabelsTask(
          labelsToAdd: ['l2']
          labelsToRemove: []
          messages: ['m1']
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

    it 'calls through to super performLocal', ->
      task = new ChangeLabelsTask
        labelsToAdd: ['l2']
        labelsToRemove: ['l1']
        threads: ['t1']
      waitsForPromise =>
        task.performLocal().then =>
          expect(task.constructor.__super__.performLocal).toHaveBeenCalled()

    describe "when object IDs are provided", ->
      beforeEach ->
        @task = new ChangeLabelsTask
          labelsToAdd: ['l2']
          labelsToRemove: ['l1']
          threads: ['t1']

      it 'resolves the objects before calling super', ->
        waitsForPromise =>
          @task.performLocal().then =>
            expect(@task.labelsToAdd).toEqual([testLabels['l2']])
            expect(@task.labelsToRemove).toEqual([testLabels['l1']])
            expect(@task.threads).toEqual([testThreads['t1']])

    describe "when objects are provided", ->
      beforeEach ->
        @task = new ChangeLabelsTask
          labelsToAdd: [testLabels['l2']]
          labelsToRemove: [testLabels['l1']]
          threads: [testThreads['t1']]

      it 'still has the objects when calling super', ->
        waitsForPromise =>
          @task.performLocal().then =>
            expect(@task.labelsToAdd).toEqual([testLabels['l2']])
            expect(@task.labelsToRemove).toEqual([testLabels['l1']])
            expect(@task.threads).toEqual([testThreads['t1']])

    describe 'change methods', ->
      describe "changesToModel", ->
        it 'properly adds labels', ->
          task = new ChangeLabelsTask
            labelsToAdd: [testLabels['l1'], testLabels['l2']]
            labelsToRemove: []
          out = task.changesToModel(testThreads['t1'])
          expect(out).toEqual(labels: [testLabels['l1'], testLabels['l2']])

        it 'properly removes labels', ->
          task = new ChangeLabelsTask
            labelsToAdd: []
            labelsToRemove: [testLabels['l1'], testLabels['l2']]
          out = task.changesToModel(testThreads['t3'])
          expect(out).toEqual(labels: [testLabels['l3']])

        it 'properly adds and removes labels', ->
          task = new ChangeLabelsTask
            labelsToAdd: [testLabels['l1'], testLabels['l2']]
            labelsToRemove: [testLabels['l2'], testLabels['l3']]
          out = task.changesToModel(testThreads['t1'])
          expect(out).toEqual(labels: [testLabels['l1']])

        it 'should return an == array of labels when no changes have occurred', ->
          thread = new Thread(id: '1', labels: [testLabels['l2'], testLabels['l3'], testLabels['l1']])
          task = new ChangeLabelsTask
            labelsToAdd: [testLabels['l3'], testLabels['l1'], testLabels['l2']]
            labelsToRemove: []
          out = task.changesToModel(thread)
          expect(_.isEqual(thread.labels, out.labels)).toBe(true)

        it 'should not modify the input thread in any way', ->
          thread = new Thread(id: '1', labels: [testLabels['l2'], testLabels['l1']])
          task = new ChangeLabelsTask
            labelsToAdd: []
            labelsToRemove: [testLabels['l2']]
          out = task.changesToModel(thread)
          expect(thread.labels.length).toBe(2)
          expect(out.labels.length).toBe(1)

      describe "requestBodyForModel", ->
        it 'returns labels:<ids> for both threads and messages', ->
          task = new ChangeLabelsTask()

          out = task.requestBodyForModel(testThreads['t3'])
          expect(out).toEqual(labels: ['l2', 'l3'])
          out = task.requestBodyForModel(testMessages['m3'])
          expect(out).toEqual(labels: ['l2', 'l3'])
