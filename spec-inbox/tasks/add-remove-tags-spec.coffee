Actions = require '../../src/flux/actions'
AddRemoveTagsTask = require '../../src/flux/tasks/add-remove-tags'
DatabaseStore = require '../../src/flux/stores/database-store'
Thread = require '../../src/flux/models/thread'
Tag = require '../../src/flux/models/tag'
_ = require 'underscore-plus'

describe "AddRemoveTagsTask", ->
  beforeEach ->
    spyOn(DatabaseStore, 'persistModel').andCallFake -> Promise.resolve()
    spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
      new Promise (resolve, reject) => resolve(new Tag({id: id, name: id}))

  describe "rollbackLocal", ->
    it "should perform the opposite changes to the thread", ->
      thread = new Thread
        tags: [
          new Tag({name: 'archive', id: 'archive'})
        ]
      task = new AddRemoveTagsTask(thread, ['archive'], ['inbox'])
      task.rollbackLocal()
      waitsFor ->
        DatabaseStore.persistModel.callCount > 0
      runs ->
        expect(thread.tagIds()).toEqual(['inbox'])

  describe "performLocal", ->
    it "should throw an exception if task has not been given a thread", ->
      badTasks = [new AddRemoveTagsTask(), new AddRemoveTagsTask(new Object)]
      goodTasks = [new AddRemoveTagsTask(new Thread)]
      caught = []
      succeeded = []

      runs ->
        [].concat(badTasks, goodTasks).forEach (task) ->
          task.performLocal()
          .then -> succeeded.push(task)
          .catch (err) -> caught.push(task)
      waitsFor ->
        succeeded.length + caught.length == 3
      runs ->
        expect(caught).toEqual(badTasks)
        expect(succeeded).toEqual(goodTasks)

    it "should trigger a persist action to commit changes to the thread to the local store", ->
      task = new AddRemoveTagsTask(new Thread(), [], [])
      task.performLocal()
      expect(DatabaseStore.persistModel).toHaveBeenCalled()

    it "should remove the tag IDs passed to the task", ->
      thread = new Thread
        tags: [
          new Tag({name: 'inbox', id: 'inbox'}),
          new Tag({name: 'unread', id: 'unread'})
        ]
      task = new AddRemoveTagsTask(thread, [], ['unread'])
      task.performLocal().catch (err) -> console.log(err.stack)
      expect(thread.tagIds().length).toBe(1)
      expect(thread.tagIds()[0]).toBe('inbox')

    it "should add the tag IDs passed to the task", ->
      thread = new Thread
        tags: [
          new Tag({name: 'inbox', id: 'inbox'})
        ]
      task = new AddRemoveTagsTask(thread, ['archive'], ['inbox'])
      task.performLocal().catch (err) -> console.log(err.stack)
      waitsFor ->
        DatabaseStore.persistModel.callCount > 0
      runs ->
        expect(thread.tagIds().length).toBe(1)
        expect(thread.tagIds()[0]).toBe('archive')


  describe "performRemote", ->
    beforeEach ->
      @thread = new Thread
        id: '1233123AEDF1'
        namespaceId: 'A12ADE'
      @task = new AddRemoveTagsTask(@thread, ['archive'], ['inbox'])

    it "should start an API request with the Draft JSON", ->
      spyOn(atom.inbox, 'makeRequest')
      @task.performRemote().catch (err) -> console.log(err.stack)
      options = atom.inbox.makeRequest.mostRecentCall.args[0]
      expect(options.path).toBe("/n/#{@thread.namespaceId}/threads/#{@thread.id}")
      expect(options.method).toBe('PUT')
      expect(options.body.add_tags[0]).toBe('archive')
      expect(options.body.remove_tags[0]).toBe('inbox')

    it "should pass returnsModel:true so that the draft is saved to the data store when returned", ->
      spyOn(atom.inbox, 'makeRequest')
      @task.performRemote().catch (err) -> console.log(err.stack)
      options = atom.inbox.makeRequest.mostRecentCall.args[0]
      expect(options.returnsModel).toBe(true)
