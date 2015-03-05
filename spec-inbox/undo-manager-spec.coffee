UndoManager = require "../src/flux/undo-manager"

describe "UndoManager", ->
  beforeEach ->
    @undoManager = new UndoManager

  it "Initializes empty", ->
    expect(@undoManager._history.length).toBe 0
    expect(@undoManager._position).toBe -1

  it "can push a history item onto the stack", ->
    @undoManager.immediatelySaveToHistory "A"
    expect(@undoManager._history[0]).toBe "A"
    expect(@undoManager._history.length).toBe 1
    expect(@undoManager.current()).toBe "A"

  it "updates the position", ->
    @undoManager.immediatelySaveToHistory "A"
    expect(@undoManager._position).toBe 0

  describe "when undoing", ->
    beforeEach ->
      @undoManager.immediatelySaveToHistory "A"
      @undoManager.immediatelySaveToHistory "AB"
      @undoManager.immediatelySaveToHistory "ABC"

    it "returns the last item on the stack", ->
      expect(@undoManager.undo()).toBe "AB"

    it "doesn't change the size of the stack", ->
      @undoManager.undo()
      expect(@undoManager._history.length).toBe 3

    it "set the position properly", ->
      @undoManager.undo()
      expect(@undoManager._position).toBe 1

    it "returns null when there's nothing to undo", ->
      @undoManager.undo()
      @undoManager.undo()
      expect(@undoManager.undo()).toBe null

  describe "when redoing", ->
    beforeEach ->
      @undoManager.immediatelySaveToHistory "X"
      @undoManager.immediatelySaveToHistory "XY"
      @undoManager.immediatelySaveToHistory "XYZ"

    it "returns the last item on the stack", ->
      @undoManager.undo()
      expect(@undoManager.redo()).toBe "XYZ"

    it "doesn't change the size of the stack", ->
      @undoManager.undo()
      @undoManager.redo()
      expect(@undoManager._history.length).toBe 3

    it "set the position properly", ->
      @undoManager.undo()
      @undoManager.redo()
      expect(@undoManager._position).toBe 2

    it "returns null when there's nothing to redo", ->
      expect(@undoManager.redo()).toBe null

  describe "when undoing and adding items", ->
    beforeEach ->
      @undoManager.immediatelySaveToHistory "1"
      @undoManager.immediatelySaveToHistory "12"
      @undoManager.immediatelySaveToHistory "123"
      @undoManager.immediatelySaveToHistory "1234"
      @undoManager.undo()
      @undoManager.undo()
      @undoManager.immediatelySaveToHistory "A"

    it "correctly sets the history", ->
      expect(@undoManager._history).toEqual ["1", "12", "A"]

    it "correctly sets the length", ->
      expect(@undoManager._history.length).toBe 3

    it "puts the correct items on the stack", ->
      @undoManager.undo()
      expect(@undoManager.redo()).toBe "A"

    it "sets the position correctly", ->
      expect(@undoManager._position).toBe 2

  describe "when the stack is full", ->
    beforeEach ->
      @undoManager._MAX_HISTORY_SIZE = 2
      @undoManager.immediatelySaveToHistory "A"
      @undoManager.immediatelySaveToHistory "AB"
      @undoManager.immediatelySaveToHistory "ABC"
      @undoManager.immediatelySaveToHistory "ABCD"

    it "correctly sets the length", ->
      expect(@undoManager._history.length).toBe 2

    it "keeps the latest histories", ->
      expect(@undoManager._history).toEqual ["ABC", "ABCD"]

    it "updates the position", ->
      expect(@undoManager._position).toBe 1
