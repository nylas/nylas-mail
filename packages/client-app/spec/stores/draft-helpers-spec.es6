import {
  Actions,
  Message,
  DraftHelpers,
} from 'nylas-exports';

import InlineStyleTransformer from '../../src/services/inline-style-transformer'
import SanitizeTransformer from '../../src/services/sanitize-transformer';


xdescribe('DraftHelpers', function describeBlock() {
  describe('prepareDraftForSyncback', () => {
    beforeEach(() => {
      spyOn(Actions, 'queueTask')
    });

    it('calls the proper functions', () => {
      const draft = new Message({
        id: "local-123",
        threadId: "thread-123",
        uploads: [{inline: true, id: 1}],
        body: "",
      });
      const session = {
        ensureCorrectAccount() { return Promise.resolve() },
        draft() { return draft },
      }
      spyOn(session, 'ensureCorrectAccount')
      spyOn(DraftHelpers, 'applyExtensionTransforms').andCallFake(async (d) => d)
      spyOn(DraftHelpers, 'removeStaleUploads');

      waitsForPromise(async () => {
        await DraftHelpers.prepareDraftForSyncback(session);
        expect(session.ensureCorrectAccount).toHaveBeenCalled();
        expect(DraftHelpers.applyExtensionTransforms).toHaveBeenCalled();
        expect(DraftHelpers.removeStaleUploads).toHaveBeenCalled();
      })
    })
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
