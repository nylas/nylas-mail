import {
  Message,
  DatabaseStore,
} from 'nylas-exports';

import BaseDraftTask from '../../src/flux/tasks/base-draft-task';

xdescribe('BaseDraftTask', function baseDraftTask() {
  describe("shouldDequeueOtherTask", () => {
    it("should dequeue instances of the same subclass for the same draft which are older", () => {
      class ATask extends BaseDraftTask {

      }
      class BTask extends BaseDraftTask {

      }

      const A = new ATask('localid-A');
      A.sequentialId = 1;
      const B1 = new BTask('localid-A');
      B1.sequentialId = 2;
      const B2 = new BTask('localid-A');
      B2.sequentialId = 3;
      const BOther = new BTask('localid-other');
      BOther.sequentialId = 4;

      expect(B1.shouldDequeueOtherTask(A)).toBe(false);
      expect(A.shouldDequeueOtherTask(B1)).toBe(false);

      expect(B2.shouldDequeueOtherTask(B1)).toBe(true);
      expect(B1.shouldDequeueOtherTask(B2)).toBe(false);

      expect(BOther.shouldDequeueOtherTask(B2)).toBe(false);
      expect(B2.shouldDequeueOtherTask(BOther)).toBe(false);
    });
  });

  describe("isDependentOnTask", () => {
    it("should always wait on older tasks for the same draft", () => {
      const A = new BaseDraftTask('localid-A');
      A.sequentialId = 1;
      const B = new BaseDraftTask('localid-A');
      B.sequentialId = 2;
      expect(B.isDependentOnTask(A)).toBe(true);
    });

    it("should not wait on newer tasks for the same draft", () => {
      const A = new BaseDraftTask('localid-A');
      A.sequentialId = 1;
      const B = new BaseDraftTask('localid-A');
      B.sequentialId = 2;
      expect(A.isDependentOnTask(B)).toBe(false)
    });

    it("should not wait on older tasks for other drafts", () => {
      const A = new BaseDraftTask('localid-other');
      A.sequentialId = 1;
      const B = new BaseDraftTask('localid-A');
      B.sequentialId = 2;
      expect(A.isDependentOnTask(B)).toBe(false);
      expect(B.isDependentOnTask(A)).toBe(false);
    });
  });

  describe("performLocal", () => {
    it("rejects if we we don't pass a draft", () => {
      const badTask = new BaseDraftTask(null)
      badTask.performLocal().then(() => {
        throw new Error("Shouldn't succeed")
      }).catch((err) => {
        expect(err.message).toBe("Attempt to call BaseDraftTask.performLocal without a draftClientId")
      });
    });
  });

  describe("refreshDraftReference", () => {
    it("should retrieve the draft by client ID, with the body, and assign it to @draft", () => {
      const draft = new Message({draft: true});
      const A = new BaseDraftTask('localid-other');
      spyOn(DatabaseStore, 'run').andReturn(Promise.resolve(draft));
      waitsForPromise(() => {
        return A.refreshDraftReference().then((resolvedValue) => {
          expect(A.draft).toEqual(draft);
          expect(resolvedValue).toEqual(draft);

          const query = DatabaseStore.run.mostRecentCall.args[0];
          expect(query.sql()).toEqual("SELECT `Message`.`data`, IFNULL(`MessageBody`.`value`, '!NULLVALUE!') AS `body`  FROM `Message` LEFT OUTER JOIN `MessageBody` ON `MessageBody`.`id` = `Message`.`id` WHERE `Message`.`client_id` = 'localid-other'  ORDER BY `Message`.`date` ASC LIMIT 1");
        });
      });
    });

    it("should throw a DraftNotFoundError error if it the response was no longer a draft", () => {
      const message = new Message({draft: false});
      const A = new BaseDraftTask('localid-other');
      spyOn(DatabaseStore, 'run').andReturn(Promise.resolve(message));
      waitsForPromise(() => {
        return A.refreshDraftReference().then(() => {
          throw new Error("Should not have resolved");
        }).catch((err) => {
          expect(err instanceof BaseDraftTask.DraftNotFoundError).toBe(true);
        })
      });
    });

    it("should throw a DraftNotFoundError error if nothing was returned", () => {
      const A = new BaseDraftTask('localid-other');
      spyOn(DatabaseStore, 'run').andReturn(Promise.resolve(null));
      waitsForPromise(() => {
        return A.refreshDraftReference().then(() => {
          throw new Error("Should not have resolved");
        }).catch((err) => {
          expect(err instanceof BaseDraftTask.DraftNotFoundError).toBe(true);
        })
      });
    });
  });
});
