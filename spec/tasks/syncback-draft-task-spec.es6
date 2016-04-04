import _ from 'underscore';
import {
  DatabaseTransaction,
  SyncbackDraftTask,
  SyncbackMetadataTask,
  DatabaseStore,
  AccountStore,
  TaskQueue,
  Contact,
  Message,
  Account,
  Actions,
  Task,
  APIError,
  NylasAPI,
} from 'nylas-exports';

const inboxError = {
  message: "No draft with public id bvn4aydxuyqlbmzowh4wraysg",
  type: "invalid_request_error",
};

const testData = {
  to: [new Contact({name: "Ben Gotow", email: "benthis.nylas.com"})],
  from: [new Contact({name: "Evan Morikawa", email: "evanthis.nylas.com"})],
  date: new Date,
  draft: true,
  subject: "Test",
  accountId: "abc123",
  body: '<body>123</body>',
};

const localDraft = () => new Message(_.extend({}, testData, {
  clientId: "local-id",
}));

const remoteDraft = () => new Message(_.extend({}, testData, {
  clientId: "local-id",
  serverId: "remoteid1234",
  threadId: '1234',
  version: 2,
}));

describe("SyncbackDraftTask", () => {
  beforeEach(() => {
    spyOn(AccountStore, "accountForEmail").andCallFake((email) =>
      new Account({clientId: 'local-abc123', serverId: 'abc123', emailAddress: email})
    );

    spyOn(DatabaseStore, "run").andCallFake((query) => {
      const clientId = query.matcherValueForModelKey('clientId')
      if (clientId === "localDraftId") {
        return Promise.resolve(localDraft());
      }
      if (clientId === "remoteDraftId") {
        return Promise.resolve(remoteDraft());
      }
      if (clientId === "missingDraftId") {
        return Promise.resolve();
      }
      return Promise.resolve();
    });

    spyOn(NylasAPI, 'incrementRemoteChangeLock');
    spyOn(NylasAPI, 'decrementRemoteChangeLock');
    spyOn(DatabaseTransaction.prototype, "persistModel").andReturn(Promise.resolve());
  });

  describe("queueing multiple tasks", () => {
    beforeEach(() => {
      this.taskA = new SyncbackDraftTask("draft-123");
      this.taskB = new SyncbackDraftTask("draft-123");
      this.taskC = new SyncbackDraftTask("draft-123");
      this.taskOther = new SyncbackDraftTask("draft-456");

      this.taskA.sequentialId = 0;
      this.taskB.sequentialId = 1;
      this.taskC.sequentialId = 2;
      TaskQueue._queue = [];
    });

    it("dequeues other SyncbackDraftTasks that haven't started yet", () => {
      // Task A is taking forever, B is waiting on it, and C gets queued.
      for (const t of [this.taskA, this.taskB, this.taskOther]) {
        t.queueState.localComplete = true;
      }

      // taskA has already started This should NOT get dequeued
      this.taskA.queueState.isProcessing = true;

      // taskB hasn't started yet! This should get dequeued
      this.taskB.queueState.isProcessing = false;

      // taskOther, while unstarted, doesn't match the draftId and should
      // not get dequeued
      this.taskOther.queueState.isProcessing = false;

      TaskQueue._queue = [this.taskA, this.taskB, this.taskOther];
      spyOn(this.taskC, "runLocal").andReturn(Promise.resolve());

      TaskQueue.enqueue(this.taskC);

      // Note that taskB is gone, taskOther was untouched, and taskC was
      // added.
      expect(TaskQueue._queue).toEqual = [this.taskA, this.taskOther, this.taskC];

      expect(this.taskC.runLocal).toHaveBeenCalled();
    });

    it("waits for any other inflight tasks to finish or error", () => {
      this.taskA.queueState.localComplete = true;
      this.taskA.queueState.isProcessing = true;
      this.taskB.queueState.localComplete = true;
      spyOn(this.taskB, "runRemote").andReturn(Promise.resolve());

      TaskQueue._queue = [this.taskA, this.taskB];

      // Since taskA has isProcessing set to true, it will just be passed
      // over. We expect taskB to fail the `_taskIsBlocked` test
      TaskQueue._processQueue();
      advanceClock(100);
      expect(TaskQueue._queue).toEqual([this.taskA, this.taskB]);
      expect(this.taskA.queueState.isProcessing).toBe(true);
      expect(this.taskB.queueState.isProcessing).toBe(false);
      expect(this.taskB.runRemote).not.toHaveBeenCalled();
    });
  });

  describe("performRemote", () => {
    beforeEach(() => {
      spyOn(NylasAPI, 'makeRequest').andReturn(Promise.resolve(remoteDraft().toJSON()))
    });

    it("does nothing if no draft can be found in the db", () => {
      const task = new SyncbackDraftTask("missingDraftId");
      waitsForPromise(() => task.performRemote().then(() => {
        expect(NylasAPI.makeRequest).not.toHaveBeenCalled();
      }));
    });

    it("should start an API request with the Message JSON", () => {
      const task = new SyncbackDraftTask("localDraftId")
      waitsForPromise(() => task.performRemote().then(() => {
        expect(NylasAPI.makeRequest).toHaveBeenCalled();
        const reqBody = NylasAPI.makeRequest.mostRecentCall.args[0].body;
        expect(reqBody.subject).toEqual(testData.subject);
        expect(reqBody.body).toEqual(testData.body);
      }));
    });

    it("should do a PUT when the draft has already been saved", () => {
      const task = new SyncbackDraftTask("remoteDraftId")
      waitsForPromise(() => task.performRemote().then(() => {
        expect(NylasAPI.makeRequest).toHaveBeenCalled();
        const options = NylasAPI.makeRequest.mostRecentCall.args[0];
        expect(options.path).toBe("/drafts/remoteid1234");
        expect(options.accountId).toBe("abc123");
        expect(options.method).toBe('PUT');
      }));
    });

    it("should do a POST when the draft is unsaved", () => {
      const task = new SyncbackDraftTask("localDraftId");
      waitsForPromise(() => task.performRemote().then(() => {
        expect(NylasAPI.makeRequest).toHaveBeenCalled();
        const options = NylasAPI.makeRequest.mostRecentCall.args[0];
        expect(options.path).toBe("/drafts");
        expect(options.accountId).toBe("abc123");
        expect(options.method).toBe('POST');
      }));
    });

    it("should apply the server ID, thread ID and version to the draft", () => {
      const task = new SyncbackDraftTask("localDraftId");
      waitsForPromise(() => task.performRemote().then(() => {
        expect(DatabaseTransaction.prototype.persistModel).toHaveBeenCalled();
        const saved = DatabaseTransaction.prototype.persistModel.calls[0].args[0];
        const remote = remoteDraft();
        expect(saved.threadId).toEqual(remote.threadId);
        expect(saved.serverId).toEqual(remote.serverId);
        expect(saved.version).toEqual(remote.version);
      }));
    });

    it("should pass returnsModel:false so that the draft can be manually removed/added to the database, accounting for its ID change", () => {
      const task = new SyncbackDraftTask("localDraftId");
      waitsForPromise(() => task.performRemote().then(() => {
        expect(NylasAPI.makeRequest).toHaveBeenCalled();
        const options = NylasAPI.makeRequest.mostRecentCall.args[0];
        expect(options.returnsModel).toBe(false);
      }));
    });

    it("should not save metadata associated to the draft when the draft has been already saved to the api", () => {
      const draft = remoteDraft();
      draft.pluginMetadata = [{pluginId: 1, value: {a: 1}}];
      const task = new SyncbackDraftTask(draft.clientId);
      spyOn(task, 'refreshDraftReference').andCallFake(() => {
        task.draft = draft;
        return Promise.resolve(draft)
      });
      spyOn(Actions, 'queueTask');
      waitsForPromise(() => task.applyResponseToDraft(draft).then(() => {
        expect(Actions.queueTask).not.toHaveBeenCalled();
      }));
    });

    it("should save metadata associated to the draft when the draft is syncbacked for the first time", () => {
      const draft = localDraft();
      draft.pluginMetadata = [{pluginId: 1, value: {a: 1}}];
      const task = new SyncbackDraftTask(draft.clientId);
      spyOn(task, 'refreshDraftReference').andCallFake(() => {
        task.draft = draft;
        return Promise.resolve();
      });
      spyOn(Actions, 'queueTask');
      waitsForPromise(() => task.applyResponseToDraft(draft).then(() => {
        const metadataTask = Actions.queueTask.mostRecentCall.args[0];
        expect(metadataTask instanceof SyncbackMetadataTask).toBe(true);
        expect(metadataTask.clientId).toEqual(draft.clientId);
        expect(metadataTask.modelClassName).toEqual('Message');
        expect(metadataTask.pluginId).toEqual(1);
      }));
    });
  });

  describe("When the api throws errors", () => {
    const stubAPI = (code, method) => {
      spyOn(NylasAPI, "makeRequest").andReturn(Promise.reject(
        new APIError({
          error: inboxError,
          response: {statusCode: code},
          body: inboxError,
          requestOptions: {method},
        })
      ));
    }

    beforeEach(() => {
      this.task = new SyncbackDraftTask("removeDraftId")
      spyOn(this.task, 'refreshDraftReference').andCallFake(() => {
        this.task.draft = remoteDraft();
        return Promise.resolve();
      });
    });

    NylasAPI.PermanentErrorCodes.forEach((code) => {
      it(`fails on API status code ${code}`, () => {
        stubAPI(code, "PUT");
        waitsForPromise(() => this.task.performRemote().then(([status, err]) => {
          expect(status).toBe(Task.Status.Failed);
          expect(this.task.refreshDraftReference).toHaveBeenCalled();
          expect(this.task.refreshDraftReference.calls.length).toBe(1);
          expect(err.statusCode).toBe(code);
        }));
      });
    });

    NylasAPI.TimeoutErrorCodes.forEach((code) => {
      it(`retries on status code ${code}`, () => {
        stubAPI(code, "PUT");
        waitsForPromise(() => this.task.performRemote().then((status) => {
          expect(status).toBe(Task.Status.Retry);
        }));
      });
    });

    it("fails on other JavaScript errors", () => {
      spyOn(NylasAPI, "makeRequest").andReturn(Promise.reject(new TypeError()));
      waitsForPromise(() => this.task.performRemote().then(([status]) => {
        expect(status).toBe(Task.Status.Failed);
        expect(this.task.refreshDraftReference).toHaveBeenCalled();
        expect(this.task.refreshDraftReference.calls.length).toBe(1);
      }));
    });
  });
});
