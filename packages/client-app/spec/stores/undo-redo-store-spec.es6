import {Actions, Task, UndoRedoStore} from 'nylas-exports'

class Undoable extends Task {
  canBeUndone() {
    return true
  }

  createIdenticalTask() {
    const t = new Undoable()
    t.id = this.id
    return t
  }
}

class PermanentTask extends Task {
  canBeUndone() {
    return false
  }
}

describe("UndoRedoStore", function undoRedoStoreSpec() {
  beforeEach(() => {
    UndoRedoStore._undo = []
    UndoRedoStore._redo = []
    spyOn(UndoRedoStore, "trigger")
    spyOn(Actions, "undoTaskId")
    spyOn(Actions, "queueTask").andCallFake((...args) => {
      UndoRedoStore._onQueue(...args)
    });
    spyOn(Actions, "queueTasks").andCallFake((...args) => {
      UndoRedoStore._onQueue(...args)
    });

    this.ids = (arrarr) => arrarr.map((arr) => arr.map((itm) => itm.id))
    this.t1 = new Undoable();
    this.t2 = new Undoable();
    this.t3 = new Undoable();
    this.t4 = new Undoable();
    this.p1 = new PermanentTask();
    this.t1.id = "t1"
    this.t2.id = "t2"
    this.t3.id = "t3"
    this.t4.id = "t4"
    this.p1.id = "p1"
  });

  it("pushes single tasks onto undo/redo", () => {
    Actions.queueTask(this.t1)
    expect(UndoRedoStore._redo).toEqual([])
    expect(UndoRedoStore._undo).toEqual([[this.t1]])
    expect(UndoRedoStore.trigger).toHaveBeenCalled()
  });

  it("pushes multiple tasks onto redo", () => {
    Actions.queueTasks([this.t1, this.t2])
    expect(UndoRedoStore._redo).toEqual([])
    expect(UndoRedoStore._undo).toEqual([[this.t1, this.t2]])
    expect(UndoRedoStore.trigger).toHaveBeenCalled()
  });

  it("only undoes task if they're all 'undoable'", () => {
    Actions.queueTask([this.t1, this.p1])
    expect(UndoRedoStore._redo).toEqual([])
    expect(UndoRedoStore._undo).toEqual([])
    expect(UndoRedoStore.trigger).not.toHaveBeenCalled()
  });

  it("refreshes redo if we get a new task", () => {
    UndoRedoStore._redo = [[this.t1, this.t2], [this.t3]]
    Actions.queueTask(this.t3)
    expect(UndoRedoStore._redo).toEqual([])
  });

  it("doesn't refresh redo if our task is itself a redo task", () => {
    UndoRedoStore._redo = [[this.t1, this.t2], [this.t3]]
    const tr = new Undoable()
    tr.isRedoTask = true
    Actions.queueTask(tr)
    expect(UndoRedoStore._redo).toEqual([[this.t1, this.t2], [this.t3]])
    expect(UndoRedoStore._undo).toEqual([[tr]])
  });

  it("runs undoTask on each group of undo tasks", () => {
    UndoRedoStore._undo = [[this.t3], [this.t1, this.t2]]
    UndoRedoStore.undo()
    expect(Actions.undoTaskId.calls.length).toBe(2)
    expect(Actions.undoTaskId.calls[0].args[0]).toBe("t1")
    expect(Actions.undoTaskId.calls[1].args[0]).toBe("t2")
    expect(UndoRedoStore._undo).toEqual([[this.t3]])
  });

  it("creates identical redo tasks and pushes on the stack", () => {
    UndoRedoStore._undo = [[this.t3], [this.t1, this.t2]]
    UndoRedoStore.undo()
    expect(UndoRedoStore._undo).toEqual([[this.t3]])
    expect(UndoRedoStore._redo[0][0].id).toBe("t1")
    expect(UndoRedoStore._redo[0][1].id).toBe("t2")
    expect(UndoRedoStore._redo.length).toBe(1)
  });

  it("redoes the latest task", () => {
    UndoRedoStore._undo = [[this.t3], [this.t1, this.t2]]
    UndoRedoStore.undo()
    UndoRedoStore.redo()
    expect(Actions.queueTasks.calls[0].args[0][0].id).toBe('t1')
    expect(Actions.queueTasks.calls[0].args[0][1].id).toBe('t2')
    expect(UndoRedoStore._undo[0]).toEqual([this.t3])
    expect(UndoRedoStore._undo[1][0].id).toBe('t1')
    expect(UndoRedoStore._undo[1][1].id).toBe('t2')
  });

  it("marks the incoming task as a redo task", () => {
    UndoRedoStore._undo = [[this.t3], [this.t1, this.t2]]
    UndoRedoStore.undo()
    UndoRedoStore.redo()
    expect(Actions.queueTasks.calls[0].args[0][0].isRedoTask).toBe(true)
    expect(Actions.queueTasks.calls[0].args[0][1].isRedoTask).toBe(true)
  });

  it("correctly follows the undo redo sequence of events", () => {
    Actions.queueTask(this.t1)
    Actions.queueTask(this.t2)
    Actions.queueTasks([this.t3, this.t4])
    expect(UndoRedoStore._undo).toEqual([[this.t1], [this.t2], [this.t3, this.t4]])
    UndoRedoStore.undo()
    UndoRedoStore.undo()
    UndoRedoStore.undo()
    UndoRedoStore.undo()
    UndoRedoStore.undo()
    expect(UndoRedoStore._undo).toEqual([])
    expect(this.ids(UndoRedoStore._redo)).toEqual([["t3", "t4"], ["t2"], ["t1"]])
    UndoRedoStore.redo()
    UndoRedoStore.redo()
    UndoRedoStore.redo()
    UndoRedoStore.redo()
    UndoRedoStore.redo()
    UndoRedoStore.redo()
    expect(this.ids(UndoRedoStore._undo)).toEqual([["t1"], ["t2"], ["t3", "t4"]])
    expect(this.ids(UndoRedoStore._redo)).toEqual([])
  });
});
