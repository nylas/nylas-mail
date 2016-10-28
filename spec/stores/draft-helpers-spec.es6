import {
  Actions,
  Message,
  DraftHelpers,
  SyncbackDraftFilesTask,
} from 'nylas-exports';

import InlineStyleTransformer from '../../src/services/inline-style-transformer'
import SanitizeTransformer from '../../src/services/sanitize-transformer';


describe('DraftHelpers', function describeBlock() {
  describe('prepareDraftForSyncback', () => {
    beforeEach(() => {
      spyOn(DraftHelpers, 'applyExtensionTransforms').andCallFake((draft) => Promise.resolve(draft))
      spyOn(Actions, 'queueTask')
    });

    it('queues tasks to upload files and send the draft', () => {
      const draft = new Message({
        clientId: "local-123",
        threadId: "thread-123",
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

  describe("prepareBodyForQuoting", () => {
    it("should transform inline styles and sanitize unsafe html", () => {
      const input = "test 123";
      spyOn(InlineStyleTransformer, 'run').andCallThrough();
      spyOn(SanitizeTransformer, 'run').andCallThrough();
      DraftHelpers.prepareBodyForQuoting(input);
      expect(InlineStyleTransformer.run).toHaveBeenCalledWith(input);
      advanceClock();
      expect(SanitizeTransformer.run).toHaveBeenCalledWith(input, SanitizeTransformer.Preset.UnsafeOnly);
    });
  });


  describe('shouldAppendQuotedText', () => {
    it('returns true if message is reply and has no marker', () => {
      const draft = {
        replyToMessageId: 1,
        body: `<div>hello!</div>`,
      }
      expect(DraftHelpers.shouldAppendQuotedText(draft)).toBe(true)
    })

    it('returns false if message is reply and has marker', () => {
      const draft = {
        replyToMessageId: 1,
        body: `<div>hello!</div><div id="n1-quoted-text-marker"></div>Quoted Text`,
      }
      expect(DraftHelpers.shouldAppendQuotedText(draft)).toBe(false)
    })

    it('returns false if message is not reply', () => {
      const draft = {
        body: `<div>hello!</div>`,
      }
      expect(DraftHelpers.shouldAppendQuotedText(draft)).toBe(false)
    })
  })
});
