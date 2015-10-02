Task = require '../../src/flux/tasks/task'
Thread = require '../../src/flux/models/thread'
ChangeUnreadTask = require '../../src/flux/tasks/change-unread-task'

describe 'ChangeUnreadTask', ->
  describe "description", ->
    it 'should include special cases for changing unread', ->
      threads = [
        new Thread(id:"id-1")
        new Thread(id:"id-2")
        new Thread(id:"id-3")
      ]
      task = new ChangeUnreadTask({threads, unread: true})
      expect(task.description()).toEqual("Marked 3 threads as unread")
      task = new ChangeUnreadTask({thread: threads[0], unread: true})
      expect(task.description()).toEqual("Marked as unread")
      task = new ChangeUnreadTask({threads, unread: false})
      expect(task.description()).toEqual("Marked 3 threads as read")
      task = new ChangeUnreadTask({thread: threads[0], unread: false})
      expect(task.description()).toEqual("Marked as read")
