import UndoStack from "../src/undo-stack";

describe("UndoStack", function UndoStackSpecs() {
  beforeEach(() => {
    this.undoManager = new UndoStack();
  });

  afterEach(() => {
    advanceClock(500);
  })

  describe("undo", () => {
    it("can restore history items, and returns null when none are available", () => {
      this.undoManager.save("A")
      this.undoManager.save("B")
      this.undoManager.save("C")
      expect(this.undoManager.current()).toBe("C")
      expect(this.undoManager.undo()).toBe("B")
      expect(this.undoManager.current()).toBe("B")
      expect(this.undoManager.undo()).toBe("A")
      expect(this.undoManager.current()).toBe("A")
      expect(this.undoManager.undo()).toBe(null)
      expect(this.undoManager.current()).toBe("A")
    });

    it("limits the undo stack to the MAX_HISTORY_SIZE", () => {
      this.undoManager._MAX_STACK_SIZE = 3
      this.undoManager.save("A")
      this.undoManager.save("B")
      this.undoManager.save("C")
      this.undoManager.save("D")
      expect(this.undoManager.current()).toBe("D")
      expect(this.undoManager.undo()).toBe("C")
      expect(this.undoManager.undo()).toBe("B")
      expect(this.undoManager.undo()).toBe(null)
      expect(this.undoManager.current()).toBe("B")
    });
  });

  describe("undo followed by redo", () => {
    it("can restore previously undone history items", () => {
      this.undoManager.save("A")
      this.undoManager.save("B")
      this.undoManager.save("C")
      expect(this.undoManager.current()).toBe("C")
      expect(this.undoManager.undo()).toBe("B")
      expect(this.undoManager.current()).toBe("B")
      expect(this.undoManager.redo()).toBe("C")
      expect(this.undoManager.current()).toBe("C")
    });

    it("cannot be used after pushing additional items", () => {
      this.undoManager.save("A")
      this.undoManager.save("B")
      this.undoManager.save("C")
      expect(this.undoManager.current()).toBe("C")
      expect(this.undoManager.undo()).toBe("B")
      this.undoManager.save("D")
      expect(this.undoManager.redo()).toBe(null)
      expect(this.undoManager.current()).toBe("D")
    });
  });
});
