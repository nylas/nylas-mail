Task = require '../../src/flux/tasks/task'
Thread = require '../../src/flux/models/thread'
NylasAPI = require '../../src/flux/nylas-api'
Attributes = require '../../src/flux/attributes'
DatabaseStore = require '../../src/flux/stores/database-store'
UpdateThreadsTask = require '../../src/flux/tasks/update-threads-task'

{APIError} = require '../../src/flux/errors'

describe 'UpdateThreadsTask', ->
  describe "description", ->
    it 'should include special cases for changing unread', ->
      objects = [
        new Thread(id:"id-1")
        new Thread(id:"id-2")
        new Thread(id:"id-3")
      ]
      task = new UpdateThreadsTask(objects, {unread: true})
      expect(task.description()).toEqual("Marked 3 threads as unread")
      task = new UpdateThreadsTask([objects[0]], {unread: true})
      expect(task.description()).toEqual("Marked as unread")
      task = new UpdateThreadsTask(objects, {unread: false})
      expect(task.description()).toEqual("Marked 3 threads as read")
      task = new UpdateThreadsTask([objects[0]], {unread: false})
      expect(task.description()).toEqual("Marked as read")

    it 'should include special cases for changing starred', ->
      objects = [
        new Thread(id:"id-1")
        new Thread(id:"id-2")
        new Thread(id:"id-3")
      ]
      task = new UpdateThreadsTask(objects, {starred: true})
      expect(task.description()).toEqual("Starred 3 threads")
      task = new UpdateThreadsTask([objects[0]], {starred: true})
      expect(task.description()).toEqual("Starred")
      task = new UpdateThreadsTask(objects, {starred: false})
      expect(task.description()).toEqual("Unstarred 3 threads")
      task = new UpdateThreadsTask([objects[0]], {starred: false})
      expect(task.description()).toEqual("Unstarred")
