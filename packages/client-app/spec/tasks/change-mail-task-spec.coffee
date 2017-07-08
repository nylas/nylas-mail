_ = require 'underscore'

{APIError,
 Folder,
 Thread,
 Message,
 Actions,
 NylasAPI,
 NylasAPIRequest,
 Query,
 DatabaseStore,
 DatabaseWriter,
 Task,
 Utils,
 ChangeMailTask,
} = require 'nylas-exports'

xdescribe "ChangeMailTask", ->
  beforeEach ->
    @threadA = new Thread(id: 'A', folders: [new Folder(id:'folderA')])
    @threadB = new Thread(id: 'B', folders: [new Folder(id:'folderB')])
    @threadC = new Thread(id: 'C', folders: [new Folder(id:'folderC')])
    @threadAChanged = new Thread(id: 'A', folders: [new Folder(id:'folderC')])

    @threadAMesage1 = new Message(id:'A1', threadId: 'A')
    @threadAMesage2 = new Message(id:'A2', threadId: 'A')
    @threadBMesage1 = new Message(id:'B1', threadId: 'B')

    threads = [@threadA, @threadB, @threadC]
    messages = [@threadAMesage1, @threadAMesage2, @threadBMesage1]

    # Instead of spying on find/findAll, we fake the evaluation of the query.
    # This allows queries to be built with findAll().where().blabla... without
    # a complex stub chain. Works since query "matchers" can be evaluated in JS
    spyOn(DatabaseStore, 'run').andCallFake (query) =>
      if query._klass is Message
        models = messages
      else if query._klass is Thread
        models = threads
      else
        throw new Error("Not stubbed!")

      models = models.filter (model) ->
        for matcher in query._matchers
          if matcher.evaluate(model) is false
            return false
        return true

      if query._singular
        models = models[0]
      Promise.resolve(models)

    @transaction = new DatabaseWriter()
    spyOn(@transaction, 'persistModels').andReturn(Promise.resolve())
    spyOn(@transaction, 'persistModel').andReturn(Promise.resolve())

  it "leaves subclasses to implement changesToModel", ->
    task = new ChangeMailTask()
    expect( => task.changesToModel() ).toThrow()

  it "leaves subclasses to implement requestBodyForModel", ->
    task = new ChangeMailTask()
    expect( => task.requestBodyForModel() ).toThrow()

  describe "createIdenticalTask", ->
    it "should return a copy of the task, but with the objects converted into object ids", ->
      task = new ChangeMailTask()
      task.messages = [@threadAMesage1, @threadAMesage2]
      clone = task.createIdenticalTask()
      expect(clone.messages).toEqual([@threadAMesage1.id, @threadAMesage2.id])

      task = new ChangeMailTask()
      task.threads = [@threadA, @threadB]
      clone = task.createIdenticalTask()
      expect(clone.threads).toEqual([@threadA.id, @threadB.id])

      task = new ChangeMailTask()
      task.threads = [@threadA.id, @threadB.id]
      clone = task.createIdenticalTask()
      expect(clone.threads).toEqual([@threadA.id, @threadB.id])

  describe "createUndoTask", ->
    it "should return a task initialized with isUndo and _restoreValues", ->
      task = new ChangeMailTask()
      task.messages = [@threadAMesage1, @threadAMesage2]
      task._restoreValues = {'A': 'bla'}
      undo = task.createUndoTask()
      expect(undo.messages).toEqual([@threadAMesage1.id, @threadAMesage2.id])
      expect(undo._restoreValues).toBe(task._restoreValues)
      expect(undo.isUndo).toBe(true)

    it "should throw if you try to make an undo task of an undo task", ->
      task = new ChangeMailTask()
      task.isUndo = true
      expect( -> task.createUndoTask()).toThrow()

    it "should throw if _restoreValues are not availble", ->
      task = new ChangeMailTask()
      task.messages = [@threadAMesage1, @threadAMesage2]
      task._restoreValues = null
      expect( -> task.createUndoTask()).toThrow()
