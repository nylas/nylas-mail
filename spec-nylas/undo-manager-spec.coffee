UndoManager = require "../src/flux/undo-manager"

describe "UndoManager", ->
  beforeEach ->
    @undoManager = new UndoManager

  afterEach ->
    advanceClock(500)

  it "Initializes empty", ->
    expect(@undoManager._history.length).toBe 0
    expect(@undoManager._markers.length).toBe 0
    expect(@undoManager._historyIndex).toBe -1
    expect(@undoManager._markerIndex).toBe -1

  it "can push a history item onto the stack", ->
    @undoManager.saveToHistory "A"
    advanceClock(500)
    expect(@undoManager._history[0]).toBe "A"
    expect(@undoManager._history.length).toBe 1
    expect(@undoManager.current()).toBe "A"

  it "updates the historyIndex", ->
    @undoManager.saveToHistory "A"
    expect(@undoManager._historyIndex).toBe 0

  it "updates the markerIndex", ->
    @undoManager.saveToHistory "A"
    advanceClock(500)
    @undoManager.saveToHistory "AB"
    @undoManager.saveToHistory "ABC"
    advanceClock(500)
    expect(@undoManager._markerIndex).toBe 1
    expect(@undoManager._historyIndex).toBe 2

  describe "when undoing", ->
    beforeEach ->
      @undoManager.saveToHistory "A"
      advanceClock(500)
      @undoManager.saveToHistory "AB"
      @undoManager.saveToHistory "ABC"

    it "returns the last item on the stack at the most recent marker", ->
      expect(@undoManager.undo()).toBe "A"

    it "doesn't change the size of the stack", ->
      @undoManager.undo()
      expect(@undoManager._history.length).toBe 3

    it "set the historyIndex properly", ->
      @undoManager.undo()
      expect(@undoManager._historyIndex).toBe 0

    it "set the markerIndex properly after a wait", ->
      advanceClock(500)
      @undoManager.undo()
      expect(@undoManager._markerIndex).toBe 0

    it "set the markerIndex properly when undo fires immediately", ->
      @undoManager.undo()
      expect(@undoManager._markerIndex).toBe 0

    it "returns null when there's nothing to undo", ->
      @undoManager.undo()
      @undoManager.undo()
      expect(@undoManager.undo()).toBe null
      expect(@undoManager._markerIndex).toBe 0

  describe "when redoing", ->
    beforeEach ->
      @undoManager.saveToHistory "X"
      advanceClock(500)
      @undoManager.saveToHistory "XY"
      @undoManager.saveToHistory "XYZ"

    it "returns the last item on the stack after a wait", ->
      advanceClock(500)
      @undoManager.undo()
      advanceClock(500)
      expect(@undoManager.redo()).toBe "XYZ"

    it "returns the last item on the stack when fired immediately", ->
      @undoManager.undo()
      expect(@undoManager.redo()).toBe "XYZ"

    it "doesn't change the size of the stack", ->
      @undoManager.undo()
      @undoManager.redo()
      expect(@undoManager._history.length).toBe 3

    it "set the historyIndex properly", ->
      @undoManager.undo()
      @undoManager.redo()
      expect(@undoManager._historyIndex).toBe 2

    it "set the markerIndex properly", ->
      @undoManager.undo()
      @undoManager.redo()
      expect(@undoManager._markerIndex).toBe 1

    it "returns null when there's nothing to redo", ->
      expect(@undoManager.redo()).toBe null
      expect(@undoManager.redo()).toBe null
      expect(@undoManager._markerIndex).toBe 1

  describe "when undoing and adding items", ->
    beforeEach ->
      @undoManager.saveToHistory "1"
      advanceClock(500)
      @undoManager.saveToHistory "12"
      @undoManager.saveToHistory "123"
      advanceClock(500)
      @undoManager.saveToHistory "1234"
      @undoManager.undo()
      @undoManager.undo()
      advanceClock(500)
      @undoManager.saveToHistory "A"
      advanceClock(500)

    it "correctly sets the history", ->
      expect(@undoManager._history).toEqual ["1", "A"]

    it "correctly sets the length", ->
      expect(@undoManager._history.length).toBe 2

    it "puts the correct items on the stack", ->
      @undoManager.undo()
      expect(@undoManager.redo()).toBe "A"

    it "sets the historyIndex correctly", ->
      expect(@undoManager._historyIndex).toBe 1

  describe "when the stack is full", ->
    beforeEach ->
      @undoManager._MAX_HISTORY_SIZE = 2
      @undoManager.saveToHistory "A"
      @undoManager.saveToHistory "AB"
      @undoManager.saveToHistory "ABC"
      @undoManager.saveToHistory "ABCD"

    it "correctly sets the length", ->
      expect(@undoManager._history.length).toBe 2

    it "keeps the latest histories", ->
      expect(@undoManager._history).toEqual ["ABC", "ABCD"]

    it "updates the historyIndex", ->
      expect(@undoManager._historyIndex).toBe 1
