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
    @_findFunction = (klass, id) =>
      if klass is Thread
        Promise.resolve(testThreads[id])
      else if klass is Message
        Promise.resolve(testMessages[id])
      else if klass is Folder
        Promise.resolve(testFolders[id])
      else
        throw new Error("Not stubbed!")

    spyOn(DatabaseStore, 'persistModel').andCallFake -> Promise.resolve()
    spyOn(DatabaseStore, 'persistModels').andCallFake -> Promise.resolve()
    spyOn(DatabaseStore, 'find').andCallFake (klass, id) =>
      @_findFunction(klass, id)

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

  describe "description", ->
    it "should include the folder name if folderOrId is a folder", ->
      taskWithFolderId = new ChangeFolderTask
        folderOrId: 'f2'
        messageIds: ['m1']
      expect(taskWithFolderId.description()).toEqual("Moved 1 message")
      taskWithFolder = new ChangeFolderTask
        folderOrId: @testFolders['f2']
        messageIds: ['m1']
      expect(taskWithFolder.description()).toEqual("Moved 1 message to MyDrafts")

    it "should correctly mention threads and messages", ->
      taskWithFolderId = new ChangeFolderTask
        folderOrId: 'f2'
        messageIds: ['m1']
      expect(@basicThreadTask.description()).toEqual("Moved 1 thread")
      taskWithFolder = new ChangeFolderTask
        folderOrId: @testFolders['f2']
        messageIds: ['m1']
      expect(@basicMessageTask.description()).toEqual("Moved 1 message to MyDrafts")

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

    it "throws an error if an undo task is passed an empty hash of undo data", ->
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
      waitsForPromise =>
        @basicThreadTask.performLocal().then ->
          expect(NylasAPI.incrementOptimisticChangeCount)
            .toHaveBeenCalledWith(Thread, 't1')

    it 'removes the objectId from the set if the object cannot be found', ->
      spyOn(@basicThreadTask, "localUpdateThread").andReturn Promise.resolve()
      spyOn(NylasAPI, "incrementOptimisticChangeCount")
      @_findFunction = (klass, id) =>
        if klass is Thread
          Promise.resolve(null)

      expect(@basicThreadTask.objectIds).toEqual(['t1'])
      waitsForPromise =>
        @basicThreadTask.performLocal().then =>
          expect(NylasAPI.incrementOptimisticChangeCount).not.toHaveBeenCalled()
          expect(@basicThreadTask.objectIds).toEqual([])

    it 'decrements optimistic changes if reverting', ->
      spyOn(@basicThreadTask, "localUpdateThread").andReturn Promise.resolve()
      spyOn(NylasAPI, "decrementOptimisticChangeCount")
      waitsForPromise =>
        @basicThreadTask.performLocal(reverting: true).then ->
          expect(NylasAPI.decrementOptimisticChangeCount)
            .toHaveBeenCalledWith(Thread, 't1')

    describe "When it's a Regular Task", ->
      it 'sets undo data and ignores messages that already have the folder we want', ->
        waitsForPromise =>
          @basicThreadTask.performLocal().then =>
            expectedData =
              originalMessageFolder:
                m2: @testFolders['f2']
                m3: @testFolders['f3']
              originalThreadFolders:
                t1: [@testFolders['f1']]
            expect(expectedData).toEqual @basicThreadTask.undoData

    it 'updates a thread with the new folder', ->
      waitsForPromise =>
        @basicThreadTask.performLocal().then =>
          thread = DatabaseStore.persistModel.calls[0].args[0]
          expect(thread.folders).toEqual [@testFolders['f1']]

    it "updates a thread's messages with the new folder and ignores messages that already have the same folder", ->
      # Our stub of DatabaseStore.findAll ignores the scoping parameter.
      # We simply return all messages.

      expectedFolder = @testFolders['f1']
      waitsForPromise =>
        @basicThreadTask.performLocal().then ->
          messages = DatabaseStore.persistModels.calls[0].args[0]
          # We expect 2 because 1 of our 3 messages already has the folder
          # we want.
          expect(messages.length).toBe 2
          for message in messages
            expect(message.folder).toEqual expectedFolder

    describe "When it's an Undo Folder task", ->
      beforeEach ->
        @undoData =
          originalMessageFolder:
            m2: @testFolders['f2']
            m3: @testFolders['f3']
          originalThreadFolders:
            t1: [@testFolders['f1']]

        testMessages.m2.folder = @testFolders['f1']
        testMessages.m3.folder = @testFolders['f1']

        @undoThreadTask = new ChangeFolderTask
          folderOrId: "f1"
          threadIds: ['t1']
          undoData: @undoData
        @undoThreadTask._isUndoTask = true

      afterEach ->
        testMessages.m2.folder = @testFolders['f2']
        testMessages.m3.folder = @testFolders['f3']

      it "Calls undoLocalUpdateThread with the thread", ->
        spyOn(@undoThreadTask, "_undoLocalUpdateThread").andCallThrough()
        waitsForPromise =>
          @undoThreadTask.performLocal().then =>
            expect(@undoThreadTask._undoLocalUpdateThread).toHaveBeenCalled()
            arg = @undoThreadTask._undoLocalUpdateThread.calls[0].args[0]
            expect(arg).toBe @testThreads['t1']

      it "updates the correct number of messages", ->
        waitsForPromise =>
          @undoThreadTask.performLocal().then =>
            messages = DatabaseStore.persistModels.calls[0].args[0]
            # It should be 2 since we only had original folder data for 2
            # of the 3 messages. The third was never changed.
            expect(messages.length).toBe 2

      it "updates the thread's messages with the original folders", ->
        waitsForPromise =>
          @undoThreadTask.performLocal().then =>
            messages = DatabaseStore.persistModels.calls[0].args[0]
            m2 = _.findWhere(messages, id: "m2")
            m3 = _.findWhere(messages, id: "m3")

            # If the task didn't work, the folders would be `f1` since
            # that's what we set in the describe block setup.
            expect(m2.folder).toBe @testFolders['f2']
            expect(m3.folder).toBe @testFolders['f3']

      it "updates the thread's folder list with the original data", ->
        waitsForPromise =>
          @undoThreadTask.performLocal().then =>
            thread = DatabaseStore.persistModel.calls[0].args[0]
            expect(thread.folders).toEqual [@testFolders['f1']]

    describe "When it's an Undo Message task", ->
      beforeEach ->
        @undoData =
          originalMessageFolder:
            m2: @testFolders['f2']

        testMessages.m1.folder = @testFolders['f1']
        testMessages.m2.folder = @testFolders['f1']

        @undoMessageTask = new ChangeFolderTask
          folderOrId: "f1"
          messageIds: ['m1', 'm2']
          undoData: @undoData
        @undoMessageTask._isUndoTask = true

      afterEach ->
        testMessages.m1.folder = @testFolders['f1']
        testMessages.m2.folder = @testFolders['f1']

      it "Calls undoLocalUpdateThread with the message", ->
        spyOn(@undoMessageTask, "_undoLocalUpdateMessage").andCallThrough()
        waitsForPromise =>
          @undoMessageTask.performLocal().then =>
            expect(@undoMessageTask._undoLocalUpdateMessage).toHaveBeenCalled()
            arg1 = @undoMessageTask._undoLocalUpdateMessage.calls[0].args[0]
            expect(arg1).toBe @testMessages['m1']

            arg2 = @undoMessageTask._undoLocalUpdateMessage.calls[1].args[0]
            expect(arg2).toBe @testMessages['m2']

      it "updates the correct number of messages", ->
        waitsForPromise =>
          @undoMessageTask.performLocal().then =>
            calls = DatabaseStore.persistModel.calls
            # It only gets called once because m1 already has the correct
            # folder.
            expect(calls.length).toBe 1

      it "updates the thread's messages with the original folders", ->
        waitsForPromise =>
          @undoMessageTask.performLocal().then =>
            m2 = DatabaseStore.persistModel.calls[0].args[0]

            expect(@testMessages.m1.folder).toBe @testFolders['f1']
            expect(m2.folder).toBe @testFolders['f2']

  describe 'performRemote', ->
    beforeEach ->
      spyOn(NylasAPI, "makeRequest").andCallFake (options) ->
        options.beforeProcessing?(options.body)
        return Promise.resolve()

    describe "when it's a regular task", ->
      describe 'when change folders on threads', ->
        beforeEach ->
          @multiThreadTask = new ChangeFolderTask
            folderOrId: "f1"
            threadIds: ['t1', 't2']
          @multiThreadTask._folderObj = @testFolders['f1']

        it 'makes a new request object for each object', ->
          waitsForPromise =>
            @multiThreadTask.performRemote().then ->
              expect(NylasAPI.makeRequest.calls.length).toBe 2

        it 'decrements the optimistic change count on each request', ->
          spyOn(NylasAPI, "decrementOptimisticChangeCount")
          waitsForPromise =>
            @multiThreadTask.performRemote().then ->
              klass = NylasAPI.decrementOptimisticChangeCount.calls[0].args[0]
              expect(NylasAPI.decrementOptimisticChangeCount.calls.length).toBe 2
              expect(klass).toBe Thread

        it 'properly passes the folder ID to the body', ->
          waitsForPromise =>
            @multiThreadTask.performRemote().then ->
              opts = NylasAPI.makeRequest.calls[0].args[0]
              expect(opts.body).toEqual folder: 'f1'

        it 'gets the correct endpoint for the thread tasks', ->
          waitsForPromise =>
            @multiThreadTask.performRemote().then ->
              opts = NylasAPI.makeRequest.calls[0].args[0]
              expect(opts.path).toEqual "/n/nsid/threads/t1"

      describe 'when change folders on messages', ->
        beforeEach ->
          @multiMessageTask = new ChangeFolderTask
            folderOrId: "f1"
            messageIds: ['m1', 'm2']
          @multiMessageTask._folderObj = @testFolders['f1']

        it 'decrements the optimistic change for messages too', ->
          spyOn(NylasAPI, "decrementOptimisticChangeCount")
          waitsForPromise =>
            @multiMessageTask.performRemote().then ->
              klass = NylasAPI.decrementOptimisticChangeCount.calls[0].args[0]
              expect(NylasAPI.decrementOptimisticChangeCount.calls.length).toBe 2
              expect(klass).toBe Message

        it 'gets the correct endpoint for the thread tasks', ->
          waitsForPromise =>
            @multiMessageTask.performRemote().then ->
              opts = NylasAPI.makeRequest.calls[0].args[0]
              expect(opts.path).toEqual "/n/nsid/messages/m1"

    describe "when it's an undo task", ->
      describe 'when change folders on threads', ->
        beforeEach ->
          @undoData =
            originalMessageFolder:
              m2: @testFolders['f2']
              m3: @testFolders['f3']
            originalThreadFolders:
              t1: [@testFolders['f1']]
              t2: [@testFolders['f1'], @testFolders['f2'], @testFolders['f3']]

          @multiThreadTask = new ChangeFolderTask
            folderOrId: "f1"
            threadIds: ['t1', 't2']
            undoData: @undoData
          @multiThreadTask._folderObj = @testFolders['f1']
          @multiThreadTask._isUndoTask = true

        it 'decrements the optimistic change count on each request', ->
          spyOn(NylasAPI, "decrementOptimisticChangeCount")
          waitsForPromise =>
            @multiThreadTask.performRemote().then ->
              klass = NylasAPI.decrementOptimisticChangeCount.calls[0].args[0]
              expect(NylasAPI.decrementOptimisticChangeCount.calls.length).toBe 2
              expect(klass).toBe Thread

        it 'properly passes the folder ID to the body', ->
          waitsForPromise =>
            @multiThreadTask.performRemote().then ->
              opts = NylasAPI.makeRequest.calls[0].args[0]
              expect(opts.body).toEqual folder: 'f1'

        it 'passes the id of the first folder if there used to be multiple folders that we tried to revert to', ->
          waitsForPromise =>
            @multiThreadTask.performRemote().then ->
              opts = NylasAPI.makeRequest.calls[1].args[0]
              expect(opts.body).toEqual folder: 'f1'

        it 'gets the correct endpoint for the thread tasks', ->
          waitsForPromise =>
            @multiThreadTask.performRemote().then ->
              opts = NylasAPI.makeRequest.calls[0].args[0]
              expect(opts.path).toEqual "/n/nsid/threads/t1"

      describe 'when change folders on messages', ->
        beforeEach ->
          @undoData =
            originalMessageFolder:
              m2: @testFolders['f2']

          @multiMessageTask = new ChangeFolderTask
            folderOrId: "f1"
            messageIds: ['m1', 'm2']
            undoData: @undoData
          @multiMessageTask._folderObj = @testFolders['f1']
          @multiMessageTask._isUndoTask = true

        it 'decrements the optimistic change for messages too', ->
          spyOn(NylasAPI, "decrementOptimisticChangeCount")
          waitsForPromise =>
            @multiMessageTask.performRemote().then ->
              klass = NylasAPI.decrementOptimisticChangeCount.calls[0].args[0]
              # It's 1 instead of 2 since we only update message 2
              expect(NylasAPI.decrementOptimisticChangeCount.calls.length).toBe 1
              expect(klass).toBe Message

        it 'properly passes the folder ID to first message', ->
          waitsForPromise =>
            @multiMessageTask.performRemote().then ->
              opts = NylasAPI.makeRequest.calls[0].args[0]
              expect(opts.body).toEqual folder: 'f2'

        it 'gets the correct endpoint for the thread tasks', ->
          waitsForPromise =>
            @multiMessageTask.performRemote().then ->
              opts = NylasAPI.makeRequest.calls[0].args[0]
              expect(opts.path).toEqual "/n/nsid/messages/m2"

  xdescribe 'performRemote', ->
    beforeEach ->
      spyOn(NylasAPI, "makeRequest").andCallFake (options) ->
        options.beforeProcessing?(options.body)
        return Promise.resolve()

      @multiThreadTask = new ChangeFolderTask
        folderOrId: ["f1", "f2"]
        folderToRemove: ["f3"]
        threadIds: ['t1', 't2']

      @multiMessageTask = new ChangeFolderTask
        folderOrId: ["f1", "f2"]
        folderToRemove: ["f3"]
        messageIds: ['m1', 'm2']

      expectedFolder = [@testFolders['f1'], @testFolders['f2']]
      @multiThreadTask._newFolder['t1'] = expectedFolder
      @multiThreadTask._newFolder['t2'] = expectedFolder
      @multiMessageTask._newFolder['m1'] = expectedFolder
      @multiMessageTask._newFolder['m2'] = expectedFolder

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

    it 'properly passes the folder IDs to the body', ->
      @multiThreadTask.performRemote().then ->
        opts = NylasAPI.makeRequest.calls[0].args[0]
        expect(opts.body).toEqual folder: ['f1', 'f2']

    it 'gets the correct endpoint for the thread tasks', ->
      @multiThreadTask.performRemote().then ->
        opts = NylasAPI.makeRequest.calls[0].args[0]
        expect(opts.path).toEqual "/n/nsid/threads/t1"

    it 'gets the correct endpoint for the message tasks', ->
      @multiMessageTask.performRemote().then ->
        opts = NylasAPI.makeRequest.calls[0].args[0]
        expect(opts.path).toEqual "/n/nsid/messages/m1"
