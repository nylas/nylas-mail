_ = require 'underscore'
Label = require('../../src/flux/models/label').default
Thread = require('../../src/flux/models/thread').default
Message = require('../../src/flux/models/message').default
Actions = require('../../src/flux/actions').default
NylasAPI = require('../../src/flux/nylas-api').default
DatabaseStore = require('../../src/flux/stores/database-store').default
ChangeLabelsTask = require('../../src/flux/tasks/change-labels-task').default
ChangeMailTask = require('../../src/flux/tasks/change-mail-task').default

{AccountStore, CategoryStore} = require 'nylas-exports'
{APIError} = require '../../src/flux/errors'
{Utils} = require '../../src/flux/models/utils'

testLabels = {}
testThreads = {}

xdescribe "ChangeLabelsTask", ->
  beforeEach ->
    # IMPORTANT: These specs do not run the performLocal logic of their superclass!
    # Tests for that logic are in change-mail-task-spec.
    spyOn(ChangeMailTask.prototype, 'performLocal').andCallFake =>
      Promise.resolve()

    spyOn(AccountStore, 'accountForItems').andReturn({id: 'a1'})
    spyOn(CategoryStore, 'getTrashCategory').andReturn name: 'trash'
    spyOn(CategoryStore, 'getInboxCategory').andReturn name: 'inbox'
    spyOn(CategoryStore, 'getSpamCategory').andReturn name: 'spam'
    spyOn(CategoryStore, 'getAllMailCategory').andReturn name: 'all'

    spyOn(DatabaseStore, 'modelify').andCallFake (klass, items) =>
      Promise.resolve items.map (item) =>
        return testLabels[item] if testLabels[item]
        return testThreads[item] if testThreads[item]
        item

    testLabels = @testLabels =
      "l1": new Label({name: 'inbox', id: 'l1', displayName: "INBOX"}),
      "l2": new Label({name: 'drafts', id: 'l2', displayName: "MyDrafts"})
      "l3": new Label({name: null, id: 'l3', displayName: "My Label"})

    testThreads = @testThreads =
      't1': new Thread(id: 't1', categories: [@testLabels['l1']])
      't2': new Thread(id: 't2', categories: _.values(@testLabels))
      't3': new Thread(id: 't3', categories: [@testLabels['l2'], @testLabels['l3']])

    @basicThreadTask = new ChangeLabelsTask
      labelsToAdd: ["l1", "l2"]
      labelsToRemove: ["l3"]
      threads: ['t1']

  describe "description", ->
    it "should include the name of the added label if it's the only mutation and it was provided as an object", ->
      task = new ChangeLabelsTask(labelsToAdd: ["l1"], labelsToRemove: [], threads: ['t1'])
      expect(task.description()).toEqual("Changed labels")
      task = new ChangeLabelsTask(labelsToAdd: [new Label(id: 'l1', displayName: 'LABEL')], labelsToRemove: [], threads: ['t1'])
      expect(task.description()).toEqual("Added LABEL")
      task = new ChangeLabelsTask(labelsToAdd: [new Label(id: 'l1', displayName: 'LABEL')], labelsToRemove: ['l2'], threads: ['t1', 't2'])
      expect(task.description()).toEqual("Moved 2 threads to LABEL")

    it "should include the name of the removed label if it's the only mutation and it was provided as an object", ->
      task = new ChangeLabelsTask(labelsToAdd: [], labelsToRemove: ["l1"], threads: ['t1'])
      expect(task.description()).toEqual("Changed labels")
      task = new ChangeLabelsTask(labelsToAdd: [], labelsToRemove: [new Label(id: 'l1', displayName: 'LABEL')], threads: ['t1'])
      expect(task.description()).toEqual("Removed LABEL")
      task = new ChangeLabelsTask(labelsToAdd: ['l2'], labelsToRemove: [new Label(id: 'l1', displayName: 'LABEL')], threads: ['t1'])
      expect(task.description()).toEqual("Changed labels")

    it "should pluralize properly", ->
      task = new ChangeLabelsTask(labelsToAdd: ["l2"], labelsToRemove: ["l1"], threads: ['t1', 't2', 't3'])
      expect(task.description()).toEqual("Changed labels on 3 threads")
      task = new ChangeLabelsTask(labelsToAdd: [new Label(id: 'l1', displayName: 'LABEL')], labelsToRemove: [], threads: ['t1', 't2'])
      expect(task.description()).toEqual("Added LABEL to 2 threads")

    it "should include special cases for some common cases", ->
      task = new ChangeLabelsTask(labelsToAdd: [new Label(name: "all")], labelsToRemove: [new Label(name: 'inbox')], threads: ['t1', 't2', 't3'])
      expect(task.description()).toEqual("Archived 3 threads")
      task = new ChangeLabelsTask(labelsToAdd: [new Label(name: "trash")], labelsToRemove: [new Label(name: 'inbox')], threads: ['t1', 't2', 't3'])
      expect(task.description()).toEqual("Trashed 3 threads")
      task = new ChangeLabelsTask(labelsToAdd: [new Label(name: "spam")], labelsToRemove: [new Label(name: 'inbox')], threads: ['t1', 't2', 't3'])
      expect(task.description()).toEqual("Marked 3 threads as Spam")
      task = new ChangeLabelsTask(labelsToAdd: [new Label(name: "inbox")], labelsToRemove: [new Label(name: 'spam')], threads: ['t1', 't2', 't3'])
      expect(task.description()).toEqual("Unmarked 3 threads as Spam")
      task = new ChangeLabelsTask(labelsToAdd: [new Label(name: "inbox")], labelsToRemove: [new Label(name: 'all')], threads: ['t1', 't2', 't3'])
      expect(task.description()).toEqual("Unarchived 3 threads")
      task = new ChangeLabelsTask(labelsToAdd: [new Label(name: "inbox")], labelsToRemove: [new Label(name: 'trash')], threads: ['t1', 't2', 't3'])
      expect(task.description()).toEqual("Removed 3 threads from Trash")
      task = new ChangeLabelsTask(labelsToAdd: [new Label(name: "inbox")], labelsToRemove: [new Label(name: 'trash')], threads: ['t1'])
      expect(task.description()).toEqual("Removed from Trash")

  describe "_ensureAndUpdateLabels", ->
    beforeEach ->
      @task = new ChangeLabelsTask()
      @account = {}

    it "does not remove `all` if attempting to remove `all` without adding `trash` or `spam`", ->
      toAdd = []
      toRemove = [{name: 'all'}]
      {labelsToAdd, labelsToRemove} = @task._ensureAndUpdateLabels(@account, toAdd, toRemove)
      expect(labelsToRemove).toEqual([])

    it "removes `trash` and `spam` if attempting to add `all` and not already removing them", ->
      toRemove = []
      toAdd = [{name: 'all'}]
      {labelsToAdd, labelsToRemove} = @task._ensureAndUpdateLabels(@account, toAdd, toRemove)
      expect(labelsToRemove).toEqual([{name: 'trash'}, {name: 'spam'}])

    it "adds `all` if removing `trash` and not adding to `all` or `spam`", ->
      toRemove = [{name: 'trash'}]
      toAdd = []
      {labelsToAdd, labelsToRemove} = @task._ensureAndUpdateLabels(@account, toAdd, toRemove)
      expect(labelsToAdd).toEqual([{name: 'all'}])

    it "removes `all` and `spam` if attempting to add `trash` and not already removing it", ->
      toRemove = []
      toAdd = [{name: 'trash'}]
      {labelsToAdd, labelsToRemove} = @task._ensureAndUpdateLabels(@account, toAdd, toRemove)
      expect(labelsToRemove).toEqual([{name: 'all'}, {name: 'spam'}])

    it "adds `all` if removing `spam` and not adding to `all` or `trash`", ->
      toRemove = [{name: 'spam'}]
      toAdd = []
      {labelsToAdd, labelsToRemove} = @task._ensureAndUpdateLabels(@account, toAdd, toRemove)
      expect(labelsToAdd).toEqual([{name: 'all'}])

    it "removes `all` and `trash` if attempting to add `spam` and not already removing it", ->
      toRemove = []
      toAdd = [{name: 'spam'}]
      {labelsToAdd, labelsToRemove} = @task._ensureAndUpdateLabels(@account, toAdd, toRemove)
      expect(labelsToRemove).toEqual([{name: 'all'}, {name: 'trash'}])

  describe "performLocal", ->
    it "should throw an exception if task has not been given a label, has been given messages, or no threads", ->
      badTasks = [
        new ChangeLabelsTask(),
        new ChangeLabelsTask(threads: [123]),
        new ChangeLabelsTask(threads: [123], messages: ["foo"]),
        new ChangeLabelsTask(labelsToAdd: ['l2'], labelsToRemove: ['l1'], messages: [123]),
        new ChangeLabelsTask(threads: "Thread"),
      ]
      goodTasks = [
        new ChangeLabelsTask(
          labelsToAdd: ['l2']
          labelsToRemove: ['l1']
          threads: ['t1']
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
          expect(task.__proto__.__proto__.performLocal).toHaveBeenCalled()

    describe "retrieveModels", ->
      describe "when object IDs are provided", ->
        beforeEach ->
          @task = new ChangeLabelsTask
            labelsToAdd: ['l2']
            labelsToRemove: ['l1']
            threads: ['t1']

        it 'resolves the objects before calling super', ->
          waitsForPromise =>
            @task.retrieveModels().then =>
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
            @task.retrieveModels().then =>
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

        it 'properly adds and removes labels, ignoring labels that are both added and removed', ->
          task = new ChangeLabelsTask
            labelsToAdd: [testLabels['l1'], testLabels['l2']]
            labelsToRemove: [testLabels['l2'], testLabels['l3']]
          out = task.changesToModel(testThreads['t1'])
          expect(out).toEqual(labels: [testLabels['l1'], testLabels['l2']])

        it 'should return an == array of labels when no changes have occurred', ->
          thread = new Thread(id: '1', categories: [testLabels['l2'], testLabels['l3'], testLabels['l1']])
          task = new ChangeLabelsTask
            labelsToAdd: [testLabels['l3'], testLabels['l1'], testLabels['l2']]
            labelsToRemove: []
          out = task.changesToModel(thread)
          expect(_.isEqual(thread.labels, out.labels)).toBe(true)

        it 'should not modify the input thread in any way', ->
          thread = new Thread(id: '1', categories: [testLabels['l2'], testLabels['l1']])
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
