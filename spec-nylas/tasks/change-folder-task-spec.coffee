_ = require 'underscore'
Folder = require '../../src/flux/models/folder'
Thread = require '../../src/flux/models/thread'
Message = require '../../src/flux/models/message'
Actions = require '../../src/flux/actions'
NylasAPI = require '../../src/flux/nylas-api'
DatabaseStore = require '../../src/flux/stores/database-store'
ChangeFolderTask = require '../../src/flux/tasks/change-folder-task'

{APIError} = require '../../src/flux/errors'
{Utils} = require '../../src/flux/models/utils'

testFolders = {}
testThreads = {}
testMessages = {}

describe "ChangeFolderTask", ->
  beforeEach ->
    spyOn(DatabaseStore, 'persistModel').andCallFake -> Promise.resolve()
    spyOn(DatabaseStore, 'persistModels').andCallFake -> Promise.resolve()
    spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
      if klass is Thread
        Promise.resolve(testThreads[id])
      else if klass is Message
        Promise.resolve(testMessages[id])
      else if klass is Folder
        Promise.resolve(testFolders[id])
      else
        throw new Error("Not stubbed!")

    spyOn(DatabaseStore, 'findAll').andCallFake (klass, finder) =>
      if klass is Message
        Promise.resolve(_.values(testMessages))
      else if klass is Thread
        Promise.resolve(_.values(testThreads))
      else if klass is Folder
        Promise.resolve(_.values(testFolders))
      else
        throw new Error("Not stubbed!")

    testFolders = @testFolders =
      "f1": new Folder({name: 'inbox', id: 'f1', displayName: "INBOX"}),
      "f2": new Folder({name: 'drafts', id: 'f2', displayName: "MyDrafts"})
      "f3": new Folder({name: null, id: 'f3', displayName: "My Folder"})

    testThreads = @testThreads =
      't1': new Thread(id: 't1', folders: [@testFolders['f1']])
      't2': new Thread(id: 't2', folders: _.values(@testFolders))
      't3': new Thread(id: 't3', folders: [@testFolders['f2'], @testFolders['f3']])

    testMessages = @testMessages =
      'm1': new Message(id: 'm1', folder: @testFolders['f1'])
      'm2': new Message(id: 'm2', folder: @testFolders['f2'])
      'm3': new Message(id: 'm3', folder: @testFolders['f3'])

    @basicThreadTask = new ChangeFolderTask
      folderOrId: "f1"
      threadIds: ['t1']

    @basicMessageTask = new ChangeFolderTask
      folderOrId: @testFolders['f2']
      messageIds: ['m1']

  describe "shouldWaitForTask", ->
    it "should return true if another, older ChangeFolderTask involves the same threads", ->
      a = new ChangeFolderTask(threadIds: ['t1', 't2', 't3'])
      a.creationDate = new Date(1000)
      b = new ChangeFolderTask(threadIds: ['t3', 't4', 't7'])
      b.creationDate = new Date(2000)
      c = new ChangeFolderTask(threadIds: ['t0', 't7'])
      c.creationDate = new Date(3000)
      expect(a.shouldWaitForTask(b)).toEqual(false)
      expect(a.shouldWaitForTask(c)).toEqual(false)
      expect(b.shouldWaitForTask(a)).toEqual(true)
      expect(c.shouldWaitForTask(a)).toEqual(false)
      expect(c.shouldWaitForTask(b)).toEqual(true)

  describe "performLocal", ->
    it "should throw an exception if task has not been given a folder", ->
      badTasks = [
        new ChangeFolderTask(),
        new ChangeFolderTask(threadIds: [123]),
        new ChangeFolderTask(threadIds: [123], messageIds: ["foo"]),
        new ChangeFolderTask(threadIds: "Thread"),
      ]
      goodTasks = [
        new ChangeFolderTask(
          folderOrId: 'f2'
          threadIds: ['t1', 't2']
        )
        new ChangeFolderTask(
          folderOrId: @testFolders['f2']
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

    it "throws an error if an undo task isn't passed undo data", ->
      t = new ChangeFolderTask
        folderOrId: 'f1'
        threadIds: ['t1', 't2']
      t._isUndoTask = true
      waitsForPromise ->
        t.performLocal().catch (error) ->
          expect(error.message).toBe "Must pass an `undoData` to rollback folder changes"
    it "throws an error if an undo task isn't passed undo data", ->
      t = new ChangeFolderTask
        folderOrId: 'f1'
        undoData: {}
        threadIds: ['t1', 't2']
      t._isUndoTask = true
      waitsForPromise ->
        t.performLocal().catch (error) ->
          expect(error.message).toBe "Must pass an `undoData` to rollback folder changes"

    it 'finds the folder to add by id', ->
      waitsForPromise =>
        @basicThreadTask.collectCategories().then (categories) =>
          expect(categories.folder).toEqual @testFolders['f1']

    it 'finds the folder to add by folder object', ->
      waitsForPromise =>
        @basicMessageTask.collectCategories().then (categories) =>
          expect(categories.folder).toEqual @testFolders['f2']

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

    describe "When it's a Regular Task", ->
      it 'sets undo data and ignores messages that already have the folder we want', ->
        @basicThreadTask.performLocal().then =>
          expectedData =
            originalMessageFolder:
              m2: @testFolders['f2']
              m3: @testFolders['f3']
            originalThreadFolders:
              t1: [@testFolders['f1']]
          expect(expectedData).toEqual @basicThreadTask.undoData

    it 'updates a thread with the new folder', ->
      @basicThreadTask.performLocal().then =>
        thread = DatabaseStore.persistModel.calls[0].args[0]
        expect(thread.folders).toEqual [@testFolders['f1']]

    it "updates a thread's messages with the new folder and ignores messages that already have the same folder", ->
      # Our stub of DatabaseStore.findAll ignores the scoping parameter.
      # We simply return all messages.

      expectedFolder = @testFolders['f1']
      @basicThreadTask.performLocal().then ->
        messages = DatabaseStore.persistModels.calls[0].args[0]
        # We expect 2 because 1 of our 3 messages already has the folder
        # we want.
        expect(messages.length).toBe 2
        for message in messages
          expect(message.folder).toEqual expectedFolder

    ## MORE TESTS COMING SOON

  #   describe "When it's an Undo Task", ->
  #
  #   xit "doesn't botter updating the message if it already has the correct folder", ->
  #     @testMessages['m4'] =
  #       new Message(id: 'm4', folder: [@testFolders['f1'], @testFolders['f2']])
  #     @testMessages['m5'] =
  #       new Message(id: 'm5', folder: [])
  #
  #     expectedFolder = [@testFolders['f1'], @testFolders['f2']]
  #     @basicThreadTask.performLocal().then =>
  #       messages = DatabaseStore.persistModels.calls[0].args[0]
  #       expect(messages.length).toBe 4
  #       for message in messages
  #         expect(message.folder).toEqual expectedFolder
  #       expect(@testMessages['m4'] not in messages).toBe true
  #
  #   xit 'updates a message with the new folder on a message task', ->
  #     expectedFolder = [@testFolders['f1'], @testFolders['f2']]
  #     @basicMessageTask.performLocal().then ->
  #       thread = DatabaseStore.persistModel.calls[0].args[0]
  #       expect(thread.folder).toEqual expectedFolder
  #
  #   xit 'saves the new folder set to an instance variable on the task so performRemote can access it later', ->
  #     expectedFolder = [@testFolders['f1'], @testFolders['f2']]
  #     @basicThreadTask.performLocal().then =>
  #       expect(@basicThreadTask._newFolder['t1']).toEqual expectedFolder
  #
  # xdescribe 'performRemote', ->
  #   beforeEach ->
  #     spyOn(NylasAPI, "makeRequest").andCallFake (options) ->
  #       options.beforeProcessing?(options.body)
  #       return Promise.resolve()
  #
  #     @multiThreadTask = new ChangeFolderTask
  #       folderOrId: ["f1", "f2"]
  #       folderToRemove: ["f3"]
  #       threadIds: ['t1', 't2']
  #
  #     @multiMessageTask = new ChangeFolderTask
  #       folderOrId: ["f1", "f2"]
  #       folderToRemove: ["f3"]
  #       messageIds: ['m1', 'm2']
  #
  #     expectedFolder = [@testFolders['f1'], @testFolders['f2']]
  #     @multiThreadTask._newFolder['t1'] = expectedFolder
  #     @multiThreadTask._newFolder['t2'] = expectedFolder
  #     @multiMessageTask._newFolder['m1'] = expectedFolder
  #     @multiMessageTask._newFolder['m2'] = expectedFolder
  #
  #   it 'makes a new request object for each object', ->
  #     @multiThreadTask.performRemote().then ->
  #       expect(NylasAPI.makeRequest.calls.length).toBe 2
  #
  #   it 'decrements the optimistic change count on each request', ->
  #     spyOn(NylasAPI, "decrementOptimisticChangeCount")
  #     @multiThreadTask.performRemote().then ->
  #       klass = NylasAPI.decrementOptimisticChangeCount.calls[0].args[0]
  #       expect(NylasAPI.decrementOptimisticChangeCount.calls.length).toBe 2
  #       expect(klass).toBe Thread
  #
  #   it 'decrements the optimistic change for messages too', ->
  #     spyOn(NylasAPI, "decrementOptimisticChangeCount")
  #     @multiMessageTask.performRemote().then ->
  #       klass = NylasAPI.decrementOptimisticChangeCount.calls[0].args[0]
  #       expect(NylasAPI.decrementOptimisticChangeCount.calls.length).toBe 2
  #       expect(klass).toBe Message
  #
  #   it 'properly passes the folder IDs to the body', ->
  #     @multiThreadTask.performRemote().then ->
  #       opts = NylasAPI.makeRequest.calls[0].args[0]
  #       expect(opts.body).toEqual folder: ['f1', 'f2']
  #
  #   it 'gets the correct endpoint for the thread tasks', ->
  #     @multiThreadTask.performRemote().then ->
  #       opts = NylasAPI.makeRequest.calls[0].args[0]
  #       expect(opts.path).toEqual "/n/nsid/threads/t1"
  #
  #   it 'gets the correct endpoint for the message tasks', ->
  #     @multiMessageTask.performRemote().then ->
  #       opts = NylasAPI.makeRequest.calls[0].args[0]
  #       expect(opts.path).toEqual "/n/nsid/messages/m1"
