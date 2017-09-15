import EmailParser from '../../lib/util/email-parser';

describe("EmailParser", function emailParser() {
  describe("__headers", () => {
    it("parses single email link", () => {
      const parser = new EmailParser({
        'list-unsubscribe': 'mailto:test@test.com',
      }, null, null);
      expect(parser.emails).toEqual(['mailto:test@test.com']);
      expect(parser.urls).toEqual([]);
      expect(parser.canUnsubscribe()).toEqual(true);
    });
    it("parses multiple links", () => {
      const parser = new EmailParser({
        'list-unsubscribe': 'https://test.com/unsubscribe, mailto:test@test.com,mailto:test2@test.com',
      }, null, null);
      expect(parser.emails).toEqual(['mailto:test@test.com', 'mailto:test2@test.com']);
      expect(parser.urls).toEqual(['https://test.com/unsubscribe']);
      expect(parser.canUnsubscribe()).toEqual(true);
    });
  });
  describe("__html", () => {
    it("parses simple html without unsubscribe link", () => {
      const parser = new EmailParser(null, "<html><a href='test'>Hello!</a></html>", null);
      expect(parser.emails).toEqual([]);
      expect(parser.urls).toEqual([]);
      expect(parser.canUnsubscribe()).toEqual(false);
    });
    it("parses simple html with unsubscribe link", () => {
      const parser = new EmailParser(null, "<html><a href='https://test.com'>Unsubscribe</a><a href='mailto:test@test.com?subject=testing'>Opt Out</a></html>", null);
      expect(parser.emails).toEqual(['mailto:test@test.com?subject=testing']);
      expect(parser.urls).toEqual(['https://test.com']);
      expect(parser.canUnsubscribe()).toEqual(true);
    });
    it("parses simple html with unsubscribe link within a sentence", () => {
      const parser = new EmailParser(null, "<html><p>Opt out of emails <a href='https://test.com'>here</a></p></html>", null);
      expect(parser.emails).toEqual([]);
      expect(parser.urls).toEqual(['https://test.com']);
      expect(parser.canUnsubscribe()).toEqual(true);
    });
    it("discovers multi-lingual unsubscribe links", () => {
      const parser = new EmailParser(null, "<html><p>Para darse de baja, haga clic <a href='https://test.com'>aquí</a></p></html>", null);
      expect(parser.emails).toEqual([]);
      expect(parser.urls).toEqual(['https://test.com']);
      expect(parser.canUnsubscribe()).toEqual(true);
    });
  });
  describe("__text", () => {
    it("parses simple text without unsubscribe link", () => {
      const parser = new EmailParser(null, null, "Hello, We regret to inform you that we don't believe in unsubscribing.");
      expect(parser.emails).toEqual([]);
      expect(parser.urls).toEqual([]);
      expect(parser.canUnsubscribe()).toEqual(false);
    });
    it("parses simple text with unsubscribe links", () => {
      const parser = new EmailParser(null, null, "Just kidding. Visit https://test.com/unsubscribe.");
      expect(parser.emails).toEqual([]);
      expect(parser.urls).toEqual(['https://test.com/unsubscribe']);
      expect(parser.canUnsubscribe()).toEqual(true);
    });
  });
});
