Actions = require '../../src/flux/actions'
NylasAPI = require '../../src/flux/nylas-api'
AddRemoveTagsTask = require '../../src/flux/tasks/add-remove-tags'
DatabaseStore = require '../../src/flux/stores/database-store'
Thread = require '../../src/flux/models/thread'
Tag = require '../../src/flux/models/tag'
_ = require 'underscore'

testThread = null

describe "AddRemoveTagsTask", ->
  beforeEach ->
    spyOn(DatabaseStore, 'persistModel').andCallFake -> Promise.resolve()
    spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
      if klass is Thread
        Promise.resolve(testThread)
      else if klass is Tag
        Promise.resolve(new Tag({id: id, name: id}))
      else
        throw new Error("Not stubbed!")

  describe "rollbackLocal", ->
    it "should perform the opposite changes to the thread", ->
      testThread = new Thread
        id: 'thread-id'
        tags: [
          new Tag({name: 'archive', id: 'archive'})
        ]
      task = new AddRemoveTagsTask(testThread, ['archive'], ['inbox'])
      task._rollbackLocal()
      waitsFor ->
        DatabaseStore.persistModel.callCount > 0
      runs ->
        testThread = DatabaseStore.persistModel.mostRecentCall.args[0]
        expect(testThread.tagIds()).toEqual(['inbox'])

  describe "performLocal", ->
    beforeEach ->
      testThread = new Thread
        id: 'thread-id'
        tags: [
          new Tag({name: 'inbox', id: 'inbox'}),
          new Tag({name: 'unread', id: 'unread'})
        ]

    it "should throw an exception if task has not been given a thread", ->
      badTasks = [new AddRemoveTagsTask()]
      goodTasks = [new AddRemoveTagsTask(testThread)]
      caught = []
      succeeded = []

      runs ->
        [].concat(badTasks, goodTasks).forEach (task) ->
          task.performLocal()
          .then -> succeeded.push(task)
          .catch (err) -> caught.push(task)
      waitsFor ->
        succeeded.length + caught.length == 2
      runs ->
        expect(caught).toEqual(badTasks)
        expect(succeeded).toEqual(goodTasks)

    it "should trigger a persist action to commit changes to the thread to the local store", ->
      task = new AddRemoveTagsTask(testThread, [], [])
      task.performLocal()
      waitsFor ->
        DatabaseStore.persistModel.callCount > 0
      runs ->
        expect(DatabaseStore.persistModel).toHaveBeenCalled()

    it "should remove the tag IDs passed to the task", ->
      task = new AddRemoveTagsTask(testThread, [], ['unread'])
      task.performLocal()
      waitsFor ->
        DatabaseStore.persistModel.callCount > 0
      runs ->
        testThread = DatabaseStore.persistModel.mostRecentCall.args[0]
        expect(testThread.tagIds().length).toBe(1)
        expect(testThread.tagIds()[0]).toBe('inbox')

    it "should add the tag IDs passed to the task", ->
      testThread = new Thread
        id: 'thread-id'
        tags: [
          new Tag({name: 'inbox', id: 'inbox'})
        ]
      task = new AddRemoveTagsTask(testThread, ['archive'], ['inbox'])
      task.performLocal()
      waitsFor ->
        DatabaseStore.persistModel.callCount > 0
      runs ->
        testThread = DatabaseStore.persistModel.mostRecentCall.args[0]
        expect(testThread.tagIds().length).toBe(1)
        expect(testThread.tagIds()[0]).toBe('archive')

    it "should never result in a tag ID being added twice", ->
      testThread = new Thread
        id: 'thread-id'
        tags: [
          new Tag({name: 'archive', id: 'archive'})
        ]
      task = new AddRemoveTagsTask(testThread, ['archive'], ['inbox'])
      task.performLocal()
      waitsFor ->
        DatabaseStore.persistModel.callCount > 0
      runs ->
        testThread = DatabaseStore.persistModel.mostRecentCall.args[0]
        expect(testThread.tagIds().length).toBe(1)
        expect(testThread.tagIds()[0]).toBe('archive')


  describe "performRemote", ->
    beforeEach ->
      testThread = new Thread
        id: '1233123AEDF1'
        namespaceId: 'A12ADE'
      @task = new AddRemoveTagsTask(testThread, ['archive'], ['inbox'])

    it "should start an API request with the Draft JSON", ->
      spyOn(NylasAPI, 'makeRequest')
      @task.performLocal()
      waitsFor ->
        DatabaseStore.persistModel.callCount > 0
      runs ->
        @task.performRemote()
        options = NylasAPI.makeRequest.mostRecentCall.args[0]
        expect(options.path).toBe("/n/#{testThread.namespaceId}/threads/#{testThread.id}")
        expect(options.method).toBe('PUT')
        expect(options.body.add_tags[0]).toBe('archive')
        expect(options.body.remove_tags[0]).toBe('inbox')

    it "should pass returnsModel:true so that the draft is saved to the data store when returned", ->
      spyOn(NylasAPI, 'makeRequest')
      @task.performLocal()
      @task.performRemote()
      options = NylasAPI.makeRequest.mostRecentCall.args[0]
      expect(options.returnsModel).toBe(true)
