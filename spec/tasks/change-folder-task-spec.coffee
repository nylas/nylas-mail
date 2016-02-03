_ = require 'underscore'
Folder = require '../../src/flux/models/folder'
Thread = require '../../src/flux/models/thread'
Message = require '../../src/flux/models/message'
Actions = require '../../src/flux/actions'
NylasAPI = require '../../src/flux/nylas-api'
Query = require '../../src/flux/models/query'
DatabaseStore = require '../../src/flux/stores/database-store'
ChangeFolderTask = require '../../src/flux/tasks/change-folder-task'

{APIError} = require '../../src/flux/errors'
{Utils} = require '../../src/flux/models/utils'

testFolders = {}
testThreads = {}
testMessages = {}

describe "ChangeFolderTask", ->
  beforeEach ->
    # IMPORTANT: These specs do not run the performLocal logic of their superclass!
    # Tests for that logic are in change-mail-task-spec.
    spyOn(ChangeFolderTask.__super__, 'performLocal').andCallFake =>
      Promise.resolve()

    spyOn(DatabaseStore, 'modelify').andCallFake (klass, items) =>
      Promise.resolve items.map (item) =>
        return testFolders[item] if testFolders[item]
        return testThreads[item] if testThreads[item]
        return testMessages[item] if testMessages[item]
        item

    testFolders = @testFolders =
      "f1": new Folder({name: 'inbox', id: 'f1', displayName: "INBOX"}),
      "f2": new Folder({name: 'drafts', id: 'f2', displayName: "MyDrafts"})
      "f3": new Folder({name: null, id: 'f3', displayName: "My Folder"})

    testThreads = @testThreads =
      't1': new Thread(id: 't1', categories: [@testFolders['f1']])
      't2': new Thread(id: 't2', categories: _.values(@testFolders))
      't3': new Thread(id: 't3', categories: [@testFolders['f2'], @testFolders['f3']])

    testMessages = @testMessages =
      'm1': new Message(id: 'm1', folder: @testFolders['f1'])
      'm2': new Message(id: 'm2', folder: @testFolders['f2'])
      'm3': new Message(id: 'm3', folder: @testFolders['f3'])

  describe "description", ->
    it "should include the folder name if folder is a folder", ->
      taskWithFolderId = new ChangeFolderTask
        folder: 'f2'
        messages: ['m1']
      expect(taskWithFolderId.description()).toEqual("Moved 1 message")
      taskWithFolder = new ChangeFolderTask
        folder: @testFolders['f2']
        messages: ['m1']
      expect(taskWithFolder.description()).toEqual("Moved 1 message to MyDrafts")

    it "should correctly mention threads and messages", ->
      taskWithFolderId = new ChangeFolderTask
        folder: 'f2'
        threads: ['t1']
      expect(taskWithFolderId.description()).toEqual("Moved 1 thread")
      taskWithFolder = new ChangeFolderTask
        folder: @testFolders['f2']
        messages: ['m1']
      expect(taskWithFolder.description()).toEqual("Moved 1 message to MyDrafts")

  describe "performLocal", ->
    it "should check that a single folder is provided, and that we have threads or messages", ->
      badTasks = [
        new ChangeFolderTask(),
        new ChangeFolderTask(threads: [123]),
        new ChangeFolderTask(threads: [123], messages: ["foo"]),
        new ChangeFolderTask(threads: "Thread"),
      ]
      goodTasks = [
        new ChangeFolderTask(
          folder: 'f2'
          threads: ['t1', 't2']
        )
        new ChangeFolderTask(
          folder: @testFolders['f2']
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
      task = new ChangeFolderTask
        folder: "f1"
        threads: ['t1']
      waitsForPromise =>
        task.performLocal().then =>
          expect(task.constructor.__super__.performLocal).toHaveBeenCalled()

    describe "when object IDs are provided", ->
      beforeEach ->
        @task = new ChangeFolderTask(folder: "f1", threads: ['t1'])

      it 'resolves the objects before calling super', ->
        waitsForPromise =>
          @task.performLocal().then =>
            expect(@task.folder).toEqual(testFolders['f1'])
            expect(@task.threads).toEqual([testThreads['t1']])

    describe "when objects are provided", ->
      beforeEach ->
        @task = new ChangeFolderTask(folder: testFolders['f1'], threads: [testThreads['t1'], testThreads['t2']])

      it 'still has the objects when calling super', ->
        waitsForPromise =>
          @task.performLocal().then =>
            expect(@task.folder).toEqual(testFolders['f1'])
            expect(@task.threads).toEqual([testThreads['t1'],testThreads['t2']])

    describe "change methods", ->
      beforeEach ->
        @message = testMessages['m1']
        @thread = testThreads['t1']
        @task = new ChangeFolderTask(folder: testFolders['f1'], threads: [testThreads['t1'], testThreads['t2']])

      describe "changesToModel", ->
        describe "if the model is a Thread", ->
          it "returns an object with a folders key, and an array with the folder", ->
            expect(@task.changesToModel(@thread)).toEqual({folders: [testFolders['f1']]})

        describe "if the model is a Message", ->
          it "returns an object with a folder key, and the folder", ->
            expect(@task.changesToModel(@message)).toEqual({folder: testFolders['f1']})

      describe "requestBodyForModel", ->
        describe "if the model is a Thread", ->
          it "returns folder: <id>, using the first available folder", ->
            @thread.folders = []
            expect(@task.requestBodyForModel(@thread)).toEqual(folder: null)
            @thread.folders = [testFolders['f1']]
            expect(@task.requestBodyForModel(@thread)).toEqual(folder: 'f1')
            @thread.folders = [testFolders['f2'], testFolders['f1']]
            expect(@task.requestBodyForModel(@thread)).toEqual(folder: 'f2')

        describe "if the model is a Message", ->
          it "returns folder: <id>, using the message folder", ->
            @message.folder = null
            expect(@task.requestBodyForModel(@message)).toEqual(folder: null)
            @message.folder = testFolders['f1']
            expect(@task.requestBodyForModel(@message)).toEqual(folder: 'f1')
