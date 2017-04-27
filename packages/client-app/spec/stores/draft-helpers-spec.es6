import {
  Actions,
  Message,
  DraftHelpers,
  DatabaseStore,
} from 'nylas-exports';

import InlineStyleTransformer from '../../src/services/inline-style-transformer'
import SanitizeTransformer from '../../src/services/sanitize-transformer';


xdescribe('DraftHelpers', function describeBlock() {
  describe('finalizeDraft', () => {
    beforeEach(() => {
      spyOn(Actions, 'queueTask')
    });

    it('calls the proper functions', () => {
      const draft = new Message({
        clientId: "local-123",
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
      spyOn(DatabaseStore, 'inTransaction').andCallFake((f) => {
        f({persistModel: m => m})
      });
      spyOn(DraftHelpers, 'removeStaleUploads');

      waitsForPromise(async () => {
        await DraftHelpers.finalizeDraft(session);
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

  describe('removeStaleUploads', () => {
    describe('returns immediately when', () => {
      beforeEach(() => {
        spyOn(DatabaseStore, 'inTransaction').andReturn(Promise.resolve(null));
      })

      it('has 0 uploads', () => {
        const draft = new Message({uploads: []});
        waitsForPromise(async () => {
          await DraftHelpers.removeStaleUploads(draft)
          expect(DatabaseStore.inTransaction).not.toHaveBeenCalled();
        })
      })

      it('has an invalid uploads field', () => {
        const draft = new Message({uploads: "uploads"});
        waitsForPromise(async () => {
          await DraftHelpers.removeStaleUploads(draft)
          expect(DatabaseStore.inTransaction).not.toHaveBeenCalled();
        })
      })
    })

    it('removes the proper uploads', () => {
      const draft = new Message({
        uploads: [
          {inline: true, id: 1},
          {inline: true, id: 2},
          {inline: false, id: 3},
        ],
        body: 'aldkfjoe cid:2 adlfkobieejlkd',
      })
      waitsForPromise(async () => {
        const {uploads} = await DraftHelpers.removeStaleUploads(draft)
        expect(uploads.length).toEqual(2);
        expect(uploads.find(u => u.id === 1)).not.toBeDefined();
        expect(uploads.find(u => u.id === 2)).toBeDefined();
        expect(uploads.find(u => u.id === 3)).toBeDefined();
      })
    })
  })
});
