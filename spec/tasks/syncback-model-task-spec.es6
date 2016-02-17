import {
  Task,
  NylasAPI,
  APIError,
  Model,
  DatabaseStore,
  SyncbackModelTask,
  DatabaseTransaction } from 'nylas-exports'

class TestTask extends SyncbackModelTask {
  getModelConstructor() {
    return Model
  }
}

describe("SyncbackModelTask", () => {
  beforeEach(() => {
    this.testModel = new Model({accountId: 'account-123'})
    spyOn(DatabaseTransaction.prototype, "persistModel")
    spyOn(DatabaseStore, "findBy").andReturn(Promise.resolve(this.testModel));

    spyOn(NylasEnv, "reportError")
    spyOn(NylasAPI, "makeRequest").andReturn(Promise.resolve({
      version: 10,
      id: "server-123",
    }))
  });

  const performRemote = (fn) => {
    window.waitsForPromise(() => {
      return this.task.performRemote().then(fn)
    });
  }

  describe("performLocal", () => {
    it("throws if basic fields are missing", () => {
      const t = new SyncbackModelTask()
      try {
        t.performLocal()
        throw new Error("Shouldn't succeed");
      } catch (e) {
        expect(e.message).toMatch(/^Must pass.*/)
      }
    });
  });

  describe("performRemote", () => {
    beforeEach(() => {
      this.task = new TestTask({
        clientId: "local-123",
        endpoint: "/test",
      })
    });

    it("fetches the latest model", () => {
      spyOn(this.task, "getLatestModel").andCallThrough()
      spyOn(this.task, "verifyModel").andCallThrough()
      performRemote(() => {
        expect(this.task.getLatestModel).toHaveBeenCalled()
        const model = this.task.verifyModel.calls[0].args[0]
        expect(model).toBe(this.testModel)
      })
    });

    it("throws an error if getLatestModel hasn't been implemented", () => {
      const bumTask = new SyncbackModelTask({clientId: 'local-123'});
      spyOn(this.task, "getModelConstructor").andCallThrough()
      window.waitsForPromise(() => {
        return bumTask.performRemote().then((err) => {
          expect(err[0]).toBe(Task.Status.Failed)
          expect(err[1].message).toMatch(/must subclass/)
        })
      });
    });

    it("verifies the model", () => {
      spyOn(this.task, "verifyModel").andCallThrough()
      spyOn(this.task, "makeRequest").andCallThrough()
      performRemote(() => {
        expect(this.task.verifyModel).toHaveBeenCalled()
        const model = this.task.makeRequest.calls[0].args[0]
        expect(model).toBe(this.testModel)
      })
    });

    it("gets the correct path and method for existing objects", () => {
      jasmine.unspy(DatabaseStore, "findBy")
      const serverModel = new Model({clientId: 'local-123', serverId: 'server-123'})

      spyOn(DatabaseStore, "findBy").andReturn(Promise.resolve(serverModel));

      spyOn(this.task, "getRequestData").andCallThrough();

      performRemote(() => {
        expect(this.task.getRequestData).toHaveBeenCalled()
        const opts = NylasAPI.makeRequest.calls[0].args[0]
        expect(opts.path).toBe("/test/server-123")
        expect(opts.method).toBe("PUT")
      });
    });

    it("gets the correct path and method for new objects", () => {
      spyOn(this.task, "getRequestData").andCallThrough();

      performRemote(() => {
        expect(this.task.getRequestData).toHaveBeenCalled()
        const opts = NylasAPI.makeRequest.calls[0].args[0]
        expect(opts.path).toBe("/test")
        expect(opts.method).toBe("POST")
      });
    });

    it("lets tasks override path and method", () => {
      class TaskMethodAndPath extends SyncbackModelTask {
        getModelConstructor() {
          return Model
        }
        getRequestData = () => {
          return {
            path: `/override`,
            method: "DELETE",
          }
        };
      }
      const task = new TaskMethodAndPath({clientId: 'local-123'});
      spyOn(task, "getRequestData").andCallThrough();
      spyOn(task, "getModelConstructor").andCallThrough()
      window.waitsForPromise(() => {
        return task.performRemote().then(() => {
          expect(task.getRequestData).toHaveBeenCalled()
          const opts = NylasAPI.makeRequest.calls[0].args[0]
          expect(opts.path).toBe("/override")
          expect(opts.method).toBe("DELETE")
        })
      });
    });

    it("makes a request with the correct data", () => {
      spyOn(this.task, "makeRequest").andCallThrough();

      // So it doesn't get changed by the time we inspect it
      spyOn(this.task, "updateLocalModel").andReturn(Promise.resolve())

      performRemote(() => {
        expect(this.task.makeRequest).toHaveBeenCalled()
        const opts = NylasAPI.makeRequest.calls[0].args[0]
        expect(opts.path).toBe("/test")
        expect(opts.method).toBe("POST")
        expect(opts.accountId).toBe("account-123")
        expect(opts.returnsModel).toBe(false)
        expect(opts.body).toEqual(this.testModel.toJSON())
      });
    });

    it("updates the local model with only the version and serverId", () => {
      spyOn(this.task, "updateLocalModel").andCallThrough()
      performRemote(() => {
        expect(this.task.updateLocalModel).toHaveBeenCalled();
        const opts = this.task.updateLocalModel.calls[0].args[0]
        expect(opts.version).toBe(10)
        expect(opts.id).toBe("server-123")
        expect(DatabaseTransaction.prototype.persistModel).toHaveBeenCalled()
        const model = DatabaseTransaction.prototype.persistModel.calls[0].args[0]
        expect(model.serverId).toBe('server-123')
        expect(model.version).toBe(10)
      });
    });

    it("retries on retry-able API errors", () => {
      jasmine.unspy(NylasAPI, "makeRequest");
      const err = new APIError({statusCode: 429});
      spyOn(NylasAPI, "makeRequest").andReturn(Promise.reject(err))
      performRemote((status) => {
        expect(status).toBe(Task.Status.Retry)
      });
    });

    it("failes on permanent errors", () => {
      jasmine.unspy(NylasAPI, "makeRequest");
      const err = new APIError({statusCode: 500});
      spyOn(NylasAPI, "makeRequest").andReturn(Promise.reject(err))
      performRemote((status) => {
        expect(status[0]).toBe(Task.Status.Failed)
        expect(status[1].statusCode).toBe(500)
      });
    });

    it("fails and notifies us on other types of errors", () => {
      const errMsg = "This is a test error"
      spyOn(this.task, "updateLocalModel").andCallFake(() => {
        throw new Error(errMsg)
      })
      performRemote((status) => {
        expect(status[0]).toBe(Task.Status.Failed)
        expect(status[1].message).toBe(errMsg)
        expect(NylasEnv.reportError).toHaveBeenCalled()
      });
    });
  });

  describe("undo/redo", () => {
    it("cant be undone", () => {
      expect(this.task.canBeUndone()).toBe(false)
    });

    it("isn't an undo task", () => {
      expect(this.task.isUndo()).toBe(false)
    });
  });
});
