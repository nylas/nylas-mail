const EmailParser = require('../../lib/util/email-parser');

describe("EmailParser", () => {
  describe("__headers", () => {
    it("parses single email link", () => {
      const parser = new EmailParser({
        'list-unsubscribe': 'mailto:test@test.com',
      }, null, null);
      expect(parser.emails).toEqual(['test@test.com']);
      expect(parser.urls).toEqual([]);
      expect(parser.canUnsubscribe()).toEqual(true);
    });
    it("parses multiple links", () => {
      const parser = new EmailParser({
        'list-unsubscribe': 'https://test.com/unsubscribe, mailto:test@test.com,mailto:test2@test.com',
      }, null, null);
      expect(parser.emails).toEqual(['test@test.com', 'test2@test.com']);
      expect(parser.urls).toEqual(['https://test.com/unsubscribe']);
      expect(parser.canUnsubscribe()).toEqual(true);
    });
  });
  describe("__html", () => {
    it("parses simple html without unsubscribe link", () => {
      const parser = new EmailParser(null, "<a href='test'>Hello!</a>", null);
      expect(parser.emails).toEqual([]);
      expect(parser.urls).toEqual([]);
      expect(parser.canUnsubscribe()).toEqual(false);
    });
    it("parses simple html with unsubscribe link", () => {
      const parser = new EmailParser(null, "<a href='test.com'>Unsubscribe</a><a href='mailto:test@test.com'>Opt Out</a>", null);
      expect(parser.emails).toEqual(['test@test.com']);
      expect(parser.urls).toEqual(['test.com']);
      expect(parser.canUnsubscribe()).toEqual(true);
    });
    it("parses simple html with unsubscribe link within a sentence", () => {
      const parser = new EmailParser(null, "<p>Opt out of emails <a href='test.com'>here</a>", null);
      expect(parser.emails).toEqual([]);
      expect(parser.urls).toEqual(['test.com']);
      expect(parser.canUnsubscribe()).toEqual(true);
    });
  });
});
