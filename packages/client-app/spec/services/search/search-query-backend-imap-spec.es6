import SearchQueryParser from '../../../src/services/search/search-query-parser'
import IMAPSearchQueryBackend from '../../../src/services/search/search-query-backend-imap'

describe('IMAPSearchQueryBackend', () => {
  it('correctly codegens TEXT', () => {
    const ast = SearchQueryParser.parse('foo');
    const result = IMAPSearchQueryBackend.compile(ast, {name: 'INBOX'});
    expect(result).toEqual([['TEXT', 'foo']]);
  });
  it('correctly codegens FROM', () => {
    const ast = SearchQueryParser.parse('from:mark');
    const result = IMAPSearchQueryBackend.compile(ast, {name: 'INBOX'});
    expect(result).toEqual([['FROM', 'mark']]);
  });
  it('correctly codegens TO', () => {
    const ast = SearchQueryParser.parse('to:mark');
    const result = IMAPSearchQueryBackend.compile(ast, {name: 'INBOX'});
    expect(result).toEqual([['TO', 'mark']]);
  });
  it('correctly codegens SUBJECT', () => {
    const ast = SearchQueryParser.parse('subject:foobar');
    const result = IMAPSearchQueryBackend.compile(ast, {name: 'INBOX'});
    expect(result).toEqual([['SUBJECT', 'foobar']]);
  });
  it('correctly codegens UNREAD', () => {
    const ast = SearchQueryParser.parse('is:unread');
    const result = IMAPSearchQueryBackend.compile(ast, {name: 'INBOX'});
    expect(result).toEqual(['UNSEEN']);
  });
  it('correctly codegens SEEN', () => {
    const ast = SearchQueryParser.parse('is:read');
    const result = IMAPSearchQueryBackend.compile(ast, {name: 'INBOX'});
    expect(result).toEqual(['SEEN']);
  });
  it('correctly codegens FLAGGED', () => {
    const ast = SearchQueryParser.parse('is:starred');
    const result = IMAPSearchQueryBackend.compile(ast, {name: 'INBOX'});
    expect(result).toEqual(['FLAGGED']);
  });
  it('correctly codegens UNFLAGGED', () => {
    const ast = SearchQueryParser.parse('is:unstarred');
    const result = IMAPSearchQueryBackend.compile(ast, {name: 'INBOX'});
    expect(result).toEqual(['UNFLAGGED']);
  });
  it('correctly codegens AND', () => {
    const ast1 = SearchQueryParser.parse('is:starred AND is:unread');
    const result1 = IMAPSearchQueryBackend.compile(ast1, {name: 'INBOX'});
    expect(result1).toEqual(['FLAGGED', 'UNSEEN']);

    const ast2 = SearchQueryParser.parse('is:starred is:unread');
    const result2 = IMAPSearchQueryBackend.compile(ast2, {name: 'INBOX'});
    expect(result2).toEqual(['FLAGGED', 'UNSEEN']);
  });
  it('correctly codegens OR', () => {
    const ast = SearchQueryParser.parse('is:starred OR is:unread');
    const result = IMAPSearchQueryBackend.compile(ast, {name: 'INBOX'});
    expect(result).toEqual([['OR', 'FLAGGED', 'UNSEEN']]);
  });
  it('correctly codegens "in:foo"', () => {
    const ast1 = SearchQueryParser.parse('is:starred OR in:foo');
    const result1 = IMAPSearchQueryBackend.compile(ast1, {name: 'INBOX'});
    expect(result1).toEqual([['OR', 'FLAGGED', '!ALL']]);
    const result2 = IMAPSearchQueryBackend.compile(ast1, {name: 'foo'});
    expect(result2).toEqual([['OR', 'FLAGGED', 'ALL']]);
    const ast2 = SearchQueryParser.parse('in:foo');
    const result3 = IMAPSearchQueryBackend.compile(ast2, {name: 'foo'});
    expect(result3).toEqual(['ALL']);
    const result4 = IMAPSearchQueryBackend.compile(ast2, {name: 'INBOX'});
    expect(result4).toEqual(['!ALL']);
  });
  it('correctly codegens has:attachment', () => {
    const ast = SearchQueryParser.parse('has:attachment');
    const result = IMAPSearchQueryBackend.compile(ast, {name: 'INBOX'});
    expect(result).toEqual([['OR', ['HEADER', 'Content-Type', 'multipart/mixed'],
                                   ['HEADER', 'Content-Type', 'multipart/related']]]);
  });
  it('correctly joins adjacent AND queries', () => {
    const ast = SearchQueryParser.parse('is:starred AND is:unread AND foo');
    const result = IMAPSearchQueryBackend.compile(ast, {name: 'INBOX'});
    expect(result).toEqual(['FLAGGED', 'UNSEEN', ['TEXT', 'foo']]);
  });
  it('correctly deduces the set of folders', () => {
    const ast1 = SearchQueryParser.parse('is:starred');
    const result1 = IMAPSearchQueryBackend.folderNamesForQuery(ast1);
    expect(result1).toEqual(IMAPSearchQueryBackend.ALL_FOLDERS());

    const ast2 = SearchQueryParser.parse('in:foo');
    const result2 = IMAPSearchQueryBackend.folderNamesForQuery(ast2);
    expect(result2).toEqual(['foo']);

    const ast3 = SearchQueryParser.parse('in:foo AND in:bar');
    const result3 = IMAPSearchQueryBackend.folderNamesForQuery(ast3);
    expect(result3).toEqual([]);

    const ast4 = SearchQueryParser.parse('in:foo OR bar');
    const result4 = IMAPSearchQueryBackend.folderNamesForQuery(ast4);
    expect(result4).toEqual(IMAPSearchQueryBackend.ALL_FOLDERS());

    const ast5 = SearchQueryParser.parse('in:foo OR in:bar');
    const result5 = IMAPSearchQueryBackend.folderNamesForQuery(ast5);
    expect(result5).toEqual(['foo', 'bar']);
  });
});
