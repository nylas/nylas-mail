import {
  Task,
  NylasAPI,
  APIError,
  CreateModelTask,
  DatabaseTransaction } from 'nylas-exports'

describe("CreateModelTask", () => {
  beforeEach(() => {
    spyOn(DatabaseTransaction.prototype, "persistModel")
  });

  it("constructs without error", () => {
    const t = new CreateModelTask()
    expect(t._rememberedToCallSuper).toBe(true)
  });

  describe("performLocal", () => {
    it("throws if basic fields are missing", () => {
      const t = new CreateModelTask()
      try {
        t.performLocal()
        throw new Error("Shouldn't succeed");
      } catch (e) {
        expect(e.message).toMatch(/^Must pass.*/)
      }
    });

    it("throws if `requiredFields` are missing", () => {
      const accountId = "a123"
      const modelName = "Metadata"
      const endpoint = "/endpoint"
      const data = {foo: "bar"}
      const requiredFields = ["stuff"]
      const t = new CreateModelTask({accountId, modelName, data, endpoint, requiredFields})
      try {
        t.performLocal()
        throw new Error("Shouldn't succeed");
      } catch (e) {
        expect(e.message).toMatch(/^Must pass data field.*/)
      }
    });

    it("throws if the model name can't be found", () => {
      const accountId = "a123"
      const modelName = "dne"
      const endpoint = "/endpoint"
      const data = {stuff: "bar"}
      const requiredFields = ["stuff"]
      const t = new CreateModelTask({accountId, modelName, data, endpoint, requiredFields})
      try {
        t.performLocal()
        throw new Error("Shouldn't succeed");
      } catch (e) {
        expect(e.message).toMatch(/^Couldn't find the class for.*/)
      }
    });

    it("persists the new model properly", () => {
      const persistFn = DatabaseTransaction.prototype.persistModel
      const accountId = "a123"
      const modelName = "Metadata"
      const endpoint = "/endpoint"
      const data = {key: "foo", value: "bar"}
      const requiredFields = ["key", "value"]
      const t = new CreateModelTask({accountId, modelName, data, endpoint, requiredFields})
      window.waitsForPromise(() => {
        return t.performLocal().then(() => {
          expect(persistFn).toHaveBeenCalled()
          const model = persistFn.calls[0].args[0]
          expect(model.constructor.name).toBe(modelName)
          expect(model.key).toBe("foo")
          expect(model.value).toBe("bar")
        });
      });
    });
  });

  describe("performRemote", () => {
    const accountId = "a123"
    const modelName = "Metadata"
    const endpoint = "/endpoint"
    const data = {key: "foo", value: "bar"}

    beforeEach(() => {
      this.task = new CreateModelTask({accountId, modelName, data, endpoint})
    });

    const performRemote = (fn) => {
      window.waitsForPromise(() => {
        return this.task.performLocal().then(() => {
          return this.task.performRemote().then(fn)
        });
      });
    }

    it("makes a POST request to the Nylas API", () => {
      spyOn(NylasAPI, "makeRequest").andReturn(Promise.resolve())
      performRemote(() => {
        const opts = NylasAPI.makeRequest.calls[0].args[0]
        expect(opts.method).toBe("POST")
        expect(opts.body.key).toBe("foo")
      })
    });

    it("marks task success on API success", () => {
      spyOn(NylasAPI, "makeRequest").andReturn(Promise.resolve())
      performRemote((status) => {
        expect(status).toBe(Task.Status.Success)
      })
    });

    it("retries on non permanent errors", () => {
      spyOn(NylasAPI, "makeRequest").andCallFake(() => {
        return Promise.reject(new APIError({statusCode: 429}))
      })
      performRemote((status) => {
        expect(status).toBe(Task.Status.Retry)
      })
    });

    it("fails on permanent errors", () => {
      const err = new APIError({statusCode: 500})
      spyOn(NylasAPI, "makeRequest").andCallFake(() => {
        return Promise.reject(err)
      })
      performRemote((status) => {
        expect(status).toEqual([Task.Status.Failed, err])
      })
    });

    it("fails on other thrown errors", () => {
      const err = new Error("foo")
      spyOn(NylasAPI, "makeRequest").andCallFake(() => {
        return Promise.reject(err)
      })
      performRemote((status) => {
        expect(status).toEqual([Task.Status.Failed, err])
      })
    });
  });

  describe("undo", () => {
    const accountId = "a123"
    const modelName = "Metadata"
    const endpoint = "/endpoint"
    const data = {key: "foo", value: "bar"}

    beforeEach(() => {
      this.task = new CreateModelTask({accountId, modelName, data, endpoint})
    });

    it("indicates it's undoable", () => {
      expect(this.task.canBeUndone()).toBe(true)
      expect(this.task.isUndo()).toBe(false)
    });

    it("creates the appropriate DestroyModelTask", () => {
      window.waitsForPromise(() => {
        return this.task.performLocal().then(() => {
          const undoTask = this.task.createUndoTask()
          expect(undoTask.constructor.name).toBe("DestroyModelTask")
          expect(undoTask.clientId).toBe(this.task.model.clientId)
          expect(undoTask.isUndo()).toBe(true)
        });
      });
    });
  });
});
