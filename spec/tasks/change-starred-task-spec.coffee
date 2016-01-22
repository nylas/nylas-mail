Task = require '../../src/flux/tasks/task'
Thread = require '../../src/flux/models/thread'
ChangeStarredTask = require '../../src/flux/tasks/change-starred-task'

describe 'ChangeStarredTask', ->
  describe "description", ->
    it 'should include special cases for changing starred', ->
      threads = [
        new Thread(id:"id-1")
        new Thread(id:"id-2")
        new Thread(id:"id-3")
      ]
      task = new ChangeStarredTask({threads:threads, starred: true})
      expect(task.description()).toEqual("Starred 3 threads")
      task = new ChangeStarredTask({thread: threads[0], starred: true})
      expect(task.description()).toEqual("Starred")
      task = new ChangeStarredTask({threads:threads, starred: false})
      expect(task.description()).toEqual("Unstarred 3 threads")
      task = new ChangeStarredTask({thread: threads[0], starred: false})
      expect(task.description()).toEqual("Unstarred")
