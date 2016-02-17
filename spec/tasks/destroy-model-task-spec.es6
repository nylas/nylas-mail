import {
  Task,
  Model,
  NylasAPI,
  DatabaseStore,
  DestroyModelTask,
  DatabaseTransaction} from 'nylas-exports'

describe("DestroyModelTask", () => {
  beforeEach(() => {
    this.existingModel = new Model()
    this.existingModel.clientId = "local-123"
    this.existingModel.serverId = "server-123"
    spyOn(DatabaseTransaction.prototype, "unpersistModel")
    spyOn(DatabaseStore, "findBy").andCallFake(() => {
      return Promise.resolve(this.existingModel)
    })

    this.defaultArgs = {
      clientId: "local-123",
      accountId: "a123",
      modelName: "Model",
      endpoint: "/endpoint",
    }
  });

  it("constructs without error", () => {
    const t = new DestroyModelTask()
    expect(t._rememberedToCallSuper).toBe(true)
  });

  describe("performLocal", () => {
    it("throws if basic fields are missing", () => {
      const t = new DestroyModelTask()
      try {
        t.performLocal()
        throw new Error("Shouldn't succeed");
      } catch (e) {
        expect(e.message).toMatch(/^Must pass.*/)
      }
    });

    it("throws if the model name can't be found", () => {
      this.defaultArgs.modelName = "dne"
      const t = new DestroyModelTask(this.defaultArgs)
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
      const t = new DestroyModelTask(this.defaultArgs)
      window.waitsForPromise(() => {
        return t.performLocal().then(() => {
          throw new Error("Shouldn't succeed")
        }).catch((err) => {
          expect(err.message).toMatch(/^Couldn't find the model with clientId.*/)
        });
      });
    });

    it("unpersists the new existing model properly", () => {
      const unpersistFn = DatabaseTransaction.prototype.unpersistModel
      const t = new DestroyModelTask(this.defaultArgs)
      window.waitsForPromise(() => {
        return t.performLocal().then(() => {
          expect(unpersistFn).toHaveBeenCalled()
          const model = unpersistFn.calls[0].args[0]
          expect(model).toBe(this.existingModel)
        });
      });
    });
  });

  describe("performRemote", () => {
    beforeEach(() => {
      this.task = new DestroyModelTask(this.defaultArgs)
    });

    const performRemote = (fn) => {
      window.waitsForPromise(() => {
        return this.task.performLocal().then(() => {
          return this.task.performRemote().then(fn)
        });
      });
    }

    it("skips request if the serverId is undefined", () => {
      window.waitsForPromise(() => {
        return this.task.performLocal().then(() => {
          this.task.serverId = null
          return this.task.performRemote().then((status)=> {
            expect(status).toEqual(Task.Status.Continue)
          })
        });
      });
    });

    it("makes a DELETE request to the Nylas API", () => {
      spyOn(NylasAPI, "makeRequest").andReturn(Promise.resolve())
      performRemote(() => {
        const opts = NylasAPI.makeRequest.calls[0].args[0]
        expect(opts.method).toBe("DELETE")
        expect(opts.path).toBe("/endpoint/server-123")
        expect(opts.accountId).toBe(this.defaultArgs.accountId)
      })
    });
  });

  // TODO, is the destroy task undoable?
  xdescribe("undo", () => {
    beforeEach(() => {
      this.task = new DestroyModelTask(this.defaultArgs)
    });

    it("indicates it's undoable", () => {
      expect(this.task.canBeUndone()).toBe(true)
      expect(this.task.isUndo()).toBe(false)
    });

    it("creates the appropriate CreateModelTask", () => {
      window.waitsForPromise(() => {
        return this.task.performLocal().then(() => {
          const undoTask = this.task.createUndoTask()
          expect(undoTask.constructor.name).toBe("CreateModelTask")
          expect(undoTask.data).toBe(this.task.oldModel)
          expect(undoTask.isUndo()).toBe(true)
        });
      });
    });
  });
});
