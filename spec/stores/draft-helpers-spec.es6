import {
  Actions,
  Message,
  DraftHelpers,
  SyncbackDraftFilesTask,
} from 'nylas-exports';

describe('DraftHelpers', function describeBlock() {
  describe('prepareForSyncback', () => {
    beforeEach(() => {
      spyOn(DraftHelpers, 'applyExtensionTransformsToDraft').andCallFake((draft) => Promise.resolve(draft))
      spyOn(Actions, 'queueTask')
    });

    it('queues tasks to upload files and send the draft', () => {
      const draft = new Message({
        clientId: "local-123",
        threadId: "thread-123",
        replyToMessageId: "message-123",
        uploads: ['stub'],
      });
      const session = {
        ensureCorrectAccount() { return Promise.resolve() },
        draft() { return draft },
      }
      runs(() => {
        DraftHelpers.prepareDraftForSyncback(session);
      });
      waitsFor(() => Actions.queueTask.calls.length > 0);
      runs(() => {
        const saveAttachments = Actions.queueTask.calls[0].args[0];
        expect(saveAttachments instanceof SyncbackDraftFilesTask).toBe(true);
        expect(saveAttachments.draftClientId).toBe(draft.clientId);
      });
    });
  });
});
