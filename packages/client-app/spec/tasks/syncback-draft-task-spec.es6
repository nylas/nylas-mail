import _ from 'underscore';
import {
  DatabaseWriter,
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
  NylasAPIRequest,
} from 'nylas-exports';

const inboxError = {
  message: "No draft with public id bvn4aydxuyqlbmzowh4wraysg",
  type: "invalid_request_error",
};

const testData = {
  to: [new Contact({name: "Ben Gotow", email: "benthis.nylas.com"})],
  from: [new Contact({name: "Evan Morikawa", email: "evanthis.nylas.com"})],
  date: new Date(),
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
  id: "remoteid1234",
  threadId: '1234',
  version: 2,
}));

xdescribe('SyncbackDraftTask', function syncbackDraftTask() {
  beforeEach(() => {
    spyOn(AccountStore, "accountForEmail").andCallFake((email) =>
      new Account({clientId: 'local-abc123', id: 'abc123', emailAddress: email})
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
    spyOn(DatabaseWriter.prototype, "persistModel").andReturn(Promise.resolve());
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
});
