import fs from 'fs';
import {
  DatabaseStore,
  DatabaseTransaction,
  Message,
  Contact,
  SyncbackDraftFilesTask,
  NylasAPI,
} from 'nylas-exports';

const DBt = DatabaseTransaction.prototype;

describe('SyncbackDraftFilesTask', function syncbackDraftFilesTask() {
  describe("with uploads", () => {
    beforeEach(() => {
      this.uploads = [
        {targetPath: '/test-file-1.png', size: 100},
        {targetPath: '/test-file-2.png', size: 100},
      ];
      this.draft = new Message({
        version: 1,
        clientId: 'client-id',
        accountId: TEST_ACCOUNT_ID,
        from: [new Contact({email: TEST_ACCOUNT_EMAIL})],
        subject: 'New Draft',
        draft: true,
        body: 'hello world',
        uploads: [].concat(this.uploads),
      });
      this.task = new SyncbackDraftFilesTask(this.draft.clientId);

      this.resolves = [];
      this.resolveAll = () => {
        for (const resolve of this.resolves) {
          resolve();
        }
        this.resolves = []
        advanceClock()
      };

      spyOn(DBt, 'persistModel');
      spyOn(fs, 'createReadStream').andReturn("stub");
      spyOn(NylasAPI, 'makeRequest').andCallFake((options) => {
        let response = this.response;

        if (options.path === '/files') {
          response = JSON.stringify([{
            id: '1234',
            account_id: TEST_ACCOUNT_ID,
            filename: options.formData.file.options.filename,
          }]);
        }

        return new Promise((resolve) => {
          this.resolves.push(() => {
            if (options.success) { options.success(response) }
            resolve(response);
          });
        });
      });
      spyOn(DatabaseStore, 'run').andReturn(Promise.resolve(this.draft));
    });

    it("should begin file uploads and not resolve until they complete", () => {
      const taskPromise = this.task.performRemote();
      advanceClock();

      // uploads should be queued, but not the send
      expect(NylasAPI.makeRequest.callCount).toEqual(2);
      expect(NylasAPI.makeRequest.calls[0].args[0].formData).toEqual({ file : { value : 'stub', options : { filename : 'test-file-1.png' } } });
      expect(NylasAPI.makeRequest.calls[1].args[0].formData).toEqual({ file : { value : 'stub', options : { filename : 'test-file-2.png' } } });

      // finish all uploads
      expect(taskPromise.isFulfilled()).toBe(false);
      this.resolveAll();
      expect(taskPromise.isFulfilled()).toBe(true);
    });

    it("should update the draft, removing uploads and adding files", () => {
      this.task.performRemote();
      advanceClock();
      this.resolveAll();
      advanceClock();
      expect(DBt.persistModel).toHaveBeenCalled();
      const draft = DBt.persistModel.mostRecentCall.args[0];
      expect(draft.files.length).toBe(2);
      expect(draft.uploads.length).toBe(0);
    });

    it("should not interfere with other uploads added to the draft during task execution", () => {
      this.task.performRemote();
      advanceClock();
      this.draft.uploads.push({targetPath: '/test-file-3.png', size: 100});
      this.resolveAll();
      advanceClock();
      expect(DBt.persistModel).toHaveBeenCalled();
      const draft = DBt.persistModel.mostRecentCall.args[0];
      expect(draft.files.length).toBe(2);
      expect(draft.uploads.length).toBe(1);
    });
  });
});
