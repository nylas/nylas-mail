import {
  Metadata,
  NylasAPI,
  DatabaseStore,
  UpdateModelTask,
  DatabaseTransaction} from 'nylas-exports'

describe("UpdateModelTask", () => {
  beforeEach(() => {
    this.existingModel = new Metadata({key: "foo", value: "bar"})
    this.existingModel.clientId = "local-123"
    this.existingModel.serverId = "server-123"
    spyOn(DatabaseTransaction.prototype, "persistModel")
    spyOn(DatabaseStore, "findBy").andCallFake(() => {
      return Promise.resolve(this.existingModel)
    })

    this.defaultArgs = {
      clientId: "local-123",
      newData: {value: "baz"},
      accountId: "a123",
      modelName: "Metadata",
      endpoint: "/endpoint",
    }
  });

  it("constructs without error", () => {
    const t = new UpdateModelTask()
    expect(t._rememberedToCallSuper).toBe(true)
  });

  describe("performLocal", () => {
    it("throws if basic fields are missing", () => {
      const t = new UpdateModelTask()
      try {
        t.performLocal()
        throw new Error("Shouldn't succeed");
      } catch (e) {
        expect(e.message).toMatch(/^Must pass.*/)
      }
    });

    it("throws if the model name can't be found", () => {
      this.defaultArgs.modelName = "dne"
      const t = new UpdateModelTask(this.defaultArgs)
      try {
        t.performLocal()
        throw new Error("Shouldn't succeed");
      } catch (e) {
        expect(e.message).toMatch(/^Couldn't find the class for.*/)
      }
    });

    it("throws if it can't find the object", () => {
      jasmine.unspy(DatabaseStore, "findBy")
      spyOn(DatabaseStore, "findBy").andCallFake(() => {
        return Promise.resolve(null)
      })
      const t = new UpdateModelTask(this.defaultArgs)
      window.waitsForPromise(() => {
        return t.performLocal().then(() => {
          throw new Error("Shouldn't succeed")
        }).catch((err) => {
          expect(err.message).toMatch(/^Couldn't find the model with clientId.*/)
        });
      });
    });

    it("persists the new existing model properly", () => {
      const persistFn = DatabaseTransaction.prototype.persistModel
      const t = new UpdateModelTask(this.defaultArgs)
      window.waitsForPromise(() => {
        return t.performLocal().then(() => {
          expect(persistFn).toHaveBeenCalled()
          const model = persistFn.calls[0].args[0]
          expect(model).toBe(this.existingModel)
        });
      });
    });
  });

  describe("performRemote", () => {
    beforeEach(() => {
      this.task = new UpdateModelTask(this.defaultArgs)
    });

    const performRemote = (fn) => {
      window.waitsForPromise(() => {
        return this.task.performLocal().then(() => {
          return this.task.performRemote().then(fn)
        });
      });
    }

    it("throws an error if the serverId is undefined", () => {
      window.waitsForPromise(() => {
        return this.task.performLocal().then(() => {
          this.task.serverId = null
          try {
            this.task.performRemote()
            throw new Error("Should fail")
          } catch (err) {
            expect(err.message).toMatch(/^Need a serverId.*/)
          }
        });
      });
    });

    it("makes a PUT request to the Nylas API", () => {
      spyOn(NylasAPI, "makeRequest").andReturn(Promise.resolve())
      performRemote(() => {
        const opts = NylasAPI.makeRequest.calls[0].args[0]
        expect(opts.method).toBe("PUT")
        expect(opts.path).toBe("/endpoint/server-123")
        expect(opts.body).toBe(this.defaultArgs.newData)
        expect(opts.accountId).toBe(this.defaultArgs.accountId)
      })
    });
  });

  describe("undo", () => {
    beforeEach(() => {
      this.task = new UpdateModelTask(this.defaultArgs)
    });

    it("indicates it's undoable", () => {
      expect(this.task.canBeUndone()).toBe(true)
      expect(this.task.isUndo()).toBe(false)
    });

    it("creates the appropriate UpdateModelTask", () => {
      window.waitsForPromise(() => {
        return this.task.performLocal().then(() => {
          const undoTask = this.task.createUndoTask()
          expect(undoTask.constructor.name).toBe("UpdateModelTask")
          expect(undoTask.newData).toBe(this.task.oldModel)
          expect(undoTask.newData.value).toBe("bar")
          expect(undoTask.isUndo()).toBe(true)
        });
      });
    });
  });
});
