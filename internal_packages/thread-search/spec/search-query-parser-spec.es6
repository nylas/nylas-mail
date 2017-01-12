import {
  ThreadQueryAST,
} from 'nylas-exports';
import {parseSearchQuery} from '../lib/search-query-parser'

const {
  SearchQueryToken,
  OrQueryExpression,
  AndQueryExpression,
  FromQueryExpression,
  ToQueryExpression,
  SubjectQueryExpression,
  GenericQueryExpression,
  TextQueryExpression,
  UnreadStatusQueryExpression,
  StarredStatusQueryExpression,
  InQueryExpression,
} = ThreadQueryAST;

const token = (text) => { return new SearchQueryToken(text); }
const and = (e1, e2) => { return new AndQueryExpression(e1, e2); }
const or = (e1, e2) => { return new OrQueryExpression(e1, e2); }
const from = (text) => { return new FromQueryExpression(text); }
const to = (text) => { return new ToQueryExpression(text); }
const subject = (text) => { return new SubjectQueryExpression(text); }
const generic = (text) => { return new GenericQueryExpression(text); }
const in_ = (text) => { return new InQueryExpression(text); }
const text = (tok) => { return new TextQueryExpression(tok); }
const unread = (status) => { return new UnreadStatusQueryExpression(status); }
const starred = (status) => { return new StarredStatusQueryExpression(status); }


describe('parseSearchQuery', () => {
  it('correctly parses simple queries', () => {
    expect(parseSearchQuery('blah').equals(
      generic(text(token('blah')))
    )).toBe(true)
    expect(parseSearchQuery('"foo bar"').equals(
      generic(text(token('foo bar')))
    )).toBe(true)
    expect(parseSearchQuery('to:blah').equals(
      to(text(token('blah')))
    )).toBe(true)
    expect(parseSearchQuery('from:blah').equals(
      from(text(token('blah')))
    )).toBe(true)
    expect(parseSearchQuery('subject:blah').equals(
      subject(text(token('blah')))
    )).toBe(true)
    expect(parseSearchQuery('to:mhahnenb@gmail.com').equals(
      to(text(token('mhahnenb@gmail.com')))
    )).toBe(true)
    expect(parseSearchQuery('to:"mhahnenb@gmail.com"').equals(
      to(text(token('mhahnenb@gmail.com')))
    )).toBe(true)
    expect(parseSearchQuery('to:"Mark mhahnenb@gmail.com"').equals(
      to(text(token('Mark mhahnenb@gmail.com')))
    )).toBe(true)
    expect(parseSearchQuery('is:unread').equals(
      unread(true)
    )).toBe(true)
    expect(parseSearchQuery('is:read').equals(
      unread(false)
    )).toBe(true)
    expect(parseSearchQuery('is:starred').equals(
      starred(true)
    )).toBe(true)
    expect(parseSearchQuery('is:unstarred').equals(
      starred(false)
    )).toBe(true)
    expect(parseSearchQuery('in:foo').equals(
      in_(text(token('foo')))
    )).toBe(true)
  });

  it('correctly parses reserved words as normal text in certain places', () => {
    expect(parseSearchQuery('to:blah').equals(
      to(text(token('blah')))
    )).toBe(true)
    expect(parseSearchQuery('to:to').equals(
      to(text(token('to')))
    )).toBe(true)
    expect(parseSearchQuery('to:subject').equals(
      to(text(token('subject')))
    )).toBe(true)
    expect(parseSearchQuery('to:from').equals(
      to(text(token('from')))
    )).toBe(true)
    expect(parseSearchQuery('to:unread').equals(
      to(text(token('unread')))
    )).toBe(true)
    expect(parseSearchQuery('to:starred').equals(
      to(text(token('starred')))
    )).toBe(true)
  });

  it('correctly parses compound queries', () => {
    expect(parseSearchQuery('foo bar').equals(
      and(generic(text(token('foo'))), generic(text(token('bar'))))
    )).toBe(true)
    expect(parseSearchQuery('foo AND bar').equals(
      and(generic(text(token('foo'))), generic(text(token('bar'))))
    )).toBe(true)
    expect(parseSearchQuery('foo OR bar').equals(
      or(generic(text(token('foo'))), generic(text(token('bar'))))
    )).toBe(true)
    expect(parseSearchQuery('to:foo OR bar').equals(
      or(to(text(token('foo'))), generic(text(token('bar'))))
    )).toBe(true)
    expect(parseSearchQuery('foo OR to:bar').equals(
      or(generic(text(token('foo'))), to(text(token('bar'))))
    )).toBe(true)
    expect(parseSearchQuery('foo bar baz').equals(
      and(generic(text(token('foo'))),
        and(generic(text(token('bar'))), generic(text(token('baz')))))
    )).toBe(true)
    expect(parseSearchQuery('foo AND bar AND baz').equals(
      and(generic(text(token('foo'))),
        and(generic(text(token('bar'))), generic(text(token('baz')))))
    )).toBe(true)
    expect(parseSearchQuery('foo OR bar AND baz').equals(
      and(
        or(generic(text(token('foo'))), generic(text(token('bar')))),
        generic(text(token('baz'))))
    )).toBe(true)
    expect(parseSearchQuery('foo OR bar OR baz').equals(
      or(generic(text(token('foo'))),
        or(generic(text(token('bar'))), generic(text(token('baz')))))
    )).toBe(true)
    expect(parseSearchQuery('foo is:unread').equals(
      and(generic(text(token('foo'))), unread(true)),
    )).toBe(true)
    expect(parseSearchQuery('is:unread foo').equals(
      and(unread(true), generic(text(token('foo'))))
    )).toBe(true)
  });
});
