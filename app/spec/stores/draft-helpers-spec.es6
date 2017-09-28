import { Actions, Message, DraftHelpers } from 'mailspring-exports';

import InlineStyleTransformer from '../../src/services/inline-style-transformer';
import SanitizeTransformer from '../../src/services/sanitize-transformer';

xdescribe('DraftHelpers', function describeBlock() {
  describe('prepareBodyForQuoting', () => {
    it('should transform inline styles and sanitize unsafe html', () => {
      const input = 'test 123';
      spyOn(InlineStyleTransformer, 'run').andCallThrough();
      spyOn(SanitizeTransformer, 'run').andCallThrough();
      DraftHelpers.prepareBodyForQuoting(input);
      expect(InlineStyleTransformer.run).toHaveBeenCalledWith(input);
      advanceClock();
      expect(SanitizeTransformer.run).toHaveBeenCalledWith(
        input,
        SanitizeTransformer.Preset.UnsafeOnly
      );
    });
  });

  describe('shouldAppendQuotedText', () => {
    it('returns true if message is reply and has no marker', () => {
      const draft = {
        replyToHeaderMessageId: 1,
        body: `<div>hello!</div>`,
      };
      expect(DraftHelpers.shouldAppendQuotedText(draft)).toBe(true);
    });

    it('returns false if message is reply and has marker', () => {
      const draft = {
        replyToHeaderMessageId: 1,
        body: `<div>hello!</div><div id="mailspring-quoted-text-marker"></div>Quoted Text`,
      };
      expect(DraftHelpers.shouldAppendQuotedText(draft)).toBe(false);
    });

    it('returns false if message is not reply', () => {
      const draft = {
        body: `<div>hello!</div>`,
      };
      expect(DraftHelpers.shouldAppendQuotedText(draft)).toBe(false);
    });
  });
});
