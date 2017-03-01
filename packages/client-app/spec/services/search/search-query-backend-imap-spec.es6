import SearchQueryParser from '../../../src/services/search/search-query-parser'
import IMAPSearchQueryBackend from '../../../src/services/search/search-query-backend-imap'

describe('IMAPSearchQueryBackend', () => {
  it('correctly codegens TEXT', () => {
    const ast = SearchQueryParser.parse('foo');
    const result = IMAPSearchQueryBackend.compile(ast);
    expect(result).toEqual([['TEXT', 'foo']]);
  });
  it('correctly codegens FROM', () => {
    const ast = SearchQueryParser.parse('from:mark');
    const result = IMAPSearchQueryBackend.compile(ast);
    expect(result).toEqual([['FROM', 'mark']]);
  });
  it('correctly codegens TO', () => {
    const ast = SearchQueryParser.parse('to:mark');
    const result = IMAPSearchQueryBackend.compile(ast);
    expect(result).toEqual([['TO', 'mark']]);
  });
  it('correctly codegens SUBJECT', () => {
    const ast = SearchQueryParser.parse('subject:foobar');
    const result = IMAPSearchQueryBackend.compile(ast);
    expect(result).toEqual([['SUBJECT', 'foobar']]);
  });
  it('correctly codegens UNREAD', () => {
    const ast = SearchQueryParser.parse('is:unread');
    const result = IMAPSearchQueryBackend.compile(ast);
    expect(result).toEqual(['UNSEEN']);
  });
  it('correctly codegens SEEN', () => {
    const ast = SearchQueryParser.parse('is:read');
    const result = IMAPSearchQueryBackend.compile(ast);
    expect(result).toEqual(['SEEN']);
  });
  it('correctly codegens FLAGGED', () => {
    const ast = SearchQueryParser.parse('is:starred');
    const result = IMAPSearchQueryBackend.compile(ast);
    expect(result).toEqual(['FLAGGED']);
  });
  it('correctly codegens UNFLAGGED', () => {
    const ast = SearchQueryParser.parse('is:unstarred');
    const result = IMAPSearchQueryBackend.compile(ast);
    expect(result).toEqual(['UNFLAGGED']);
  });
  it('correctly codegens AND', () => {
    const ast1 = SearchQueryParser.parse('is:starred AND is:unread');
    const result1 = IMAPSearchQueryBackend.compile(ast1);
    expect(result1).toEqual(['FLAGGED', 'UNSEEN']);

    const ast2 = SearchQueryParser.parse('is:starred is:unread');
    const result2 = IMAPSearchQueryBackend.compile(ast2);
    expect(result2).toEqual(['FLAGGED', 'UNSEEN']);
  });
  it('correctly codegens OR', () => {
    const ast = SearchQueryParser.parse('is:starred OR is:unread');
    const result = IMAPSearchQueryBackend.compile(ast);
    expect(result).toEqual([['OR', 'FLAGGED', 'UNSEEN']]);
  });
  it('correctly ignores "in:foo"', () => {
    const ast = SearchQueryParser.parse('is:starred OR in:foo');
    const result = IMAPSearchQueryBackend.compile(ast);
    expect(result).toEqual([['OR', 'FLAGGED', 'ALL']]);
  });
  it('correctly joins adjacent AND queries', () => {
    const ast = SearchQueryParser.parse('is:starred AND is:unread AND foo');
    const result = IMAPSearchQueryBackend.compile(ast);
    expect(result).toEqual(['FLAGGED', 'UNSEEN', ['TEXT', 'foo']]);
  });
});
