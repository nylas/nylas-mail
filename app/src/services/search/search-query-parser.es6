import {
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
  HasAttachmentQueryExpression,
} from './search-query-ast';

const nextStringToken = (text) => {
  if (text[0] !== '"') {
    throw new Error('Expected string token to begin with double quote (")');
  }
  if (text.length < 2) {
    throw new Error('Expected string but ran out of input');
  }
  let pos = 1;
  while (pos < text.length) {
    const c = text[pos];
    if (c === '"') {
      return [new SearchQueryToken(text.substring(1, pos)), text.substring(pos + 1)];
    }
    pos += 1;
  }
  throw new Error('Expected string but ran out of input');
};

const isWhitespace = (c) => {
  switch (c) {
    case ' ':
    case '\t':
    case '\n': return true;
    default: return false;
  }
};

const consumeWhitespace = (text) => {
  let pos = 0;
  while (pos < text.length && isWhitespace(text[pos])) {
    pos += 1;
  }
  return text.substring(pos);
};

const reserved = [
  '(',
  ')',
  ':',
  'is',
  'read',
  'unread',
  'starred',
  'and',
  'or',
  'from',
  'to',
  'subject',
  'in',
  'has',
  'attachment',
];

const mightBeReserved = (text) => {
  for (const r of reserved) {
    if (r.startsWith(text) || r.toUpperCase().startsWith(text)) {
      return true;
    }
  }
  return false;
};

const isValidNonStringChar = (c) => {
  switch (c) {
    case '(':
    case ')':
    case ':': return false;
    default: return !isWhitespace(c);
  }
};

const isValidNonStringText = (text) => {
  if (text.length < 1) {
    return false;
  }

  for (const c of text) {
    if (!isValidNonStringChar(c)) {
      return false;
    }
  }
  return true;
};

const nextToken = (text) => {
  const newText = consumeWhitespace(text);
  if (newText.length === 0) {
    return [null, newText];
  }

  if (newText[0] === '"') {
    return nextStringToken(newText);
  }

  let isReserved = true;
  let pos = 0;
  while (pos < newText.length) {
    if (isWhitespace(newText[pos])) {
      return [new SearchQueryToken(newText.substring(0, pos)), newText.substring(pos)];
    }

    const curr = newText.substring(0, pos + 1);
    if (isReserved) {
      // We no longer have a reserved keyword.
      if (!mightBeReserved(curr)) {
        // We became an invalid non-reserved token so return the previous pos.
        if (!isValidNonStringText(curr)) {
          return [new SearchQueryToken(newText.substring(0, pos)), newText.substring(pos)];
        }
        // We're still a valid token but we're no longer reserved.
        isReserved = false;
      }
    } else {
      // We're not reserved and we become invalid so go back.
      if (!isReserved && !isValidNonStringText(curr)) {
        return [new SearchQueryToken(newText.substring(0, pos)), newText.substring(pos)];
      }
    }
    pos += 1;
  }
  return [new SearchQueryToken(newText.substring(0, pos + 1)), newText.substring(pos + 1)];
};

/*
 * query: and_query+
 *
 * and_query: or_query [and_query_rest]
 * and_query_rest: AND and_query
 *
 * or_query: simple_query [or_query_rest]
 * or_query_rest: OR or_query
 *
 * simple_query: TEXT
 *             | from_query
 *             | to_query
 *             | subject_query
 *             | paren_query
 *             | is_query
 *             | has_query
 *
 * from_query: FROM COLON TEXT
 * to_query: TO COLON TEXT
 * subject_query: SUBJECT COLON TEXT
 * paren_query: LPAREN query RPAREN
 * is_query: IS COLON is_query_rest
 * is_query_rest: read_cond
 *              | starred_cond
 * has_query: HAS COLON ATTACHMENT
 * read_cond: READ | UNREAD
 * starred_cond: STARRED | UNSTARRED
 * in_query: IN COLON TEXT
 *
 * TEXT: STRING
 *     | [^\s]+
 * STRING: DQUOTE [^"]* DQUOTE
 */
const consumeExpectedToken = (text, token) => {
  const [tok, afterTok] = nextToken(text);
  if (tok.s !== token) {
    throw new Error(`Expected '${token}', got '${tok.s}'`);
  }
  return afterTok;
};

const parseText = (text) => {
  const [tok, afterTok] = nextToken(text);
  if (tok === null) {
    throw new Error('Expected text but none available');
  }
  return [new TextQueryExpression(tok), afterTok];
};

const parseIsQuery = (text) => {
  const afterColon = consumeExpectedToken(text, ':');
  const [tok, afterTok] = nextToken(afterColon);
  if (tok === null) {
    return null;
  }
  const tokText = tok.s.toUpperCase();
  switch (tokText) {
    case 'READ':
    case 'UNREAD': {
      return [new UnreadStatusQueryExpression(tokText === 'UNREAD'), afterTok];
    }
    case 'STARRED':
    case 'UNSTARRED': {
      return [new StarredStatusQueryExpression(tokText === 'STARRED'), afterTok];
    }
    default: break;
  }
  return null;
};

const parseHasQuery = (text) => {
  const afterColon = consumeExpectedToken(text, ':');
  const [tok, afterTok] = nextToken(afterColon);
  if (tok === null) {
    return null;
  }
  const tokText = tok.s.toUpperCase();
  switch (tokText) {
    case 'ATTACHMENT': {
      return [new HasAttachmentQueryExpression(), afterTok];
    }
    default: break;
  }
  return null;
};

let parseQuery = null; // Satisfy our robot overlords.
const parseSimpleQuery = (text) => {
  const [tok, afterTok] = nextToken(text);
  if (tok === null) {
    return [null, afterTok];
  }
  if (tok.s === '(') {
    const [exp, afterExp] = parseQuery(afterTok);
    const afterRparen = consumeExpectedToken(afterExp, ')');
    return [exp, afterRparen];
  }

  if (tok.s.toUpperCase() === 'TO') {
    const afterColon = consumeExpectedToken(afterTok, ':');
    const [txt, afterTxt] = parseText(afterColon);
    return [new ToQueryExpression(txt), afterTxt];
  }

  if (tok.s.toUpperCase() === 'FROM') {
    const afterColon = consumeExpectedToken(afterTok, ':');
    const [txt, afterTxt] = parseText(afterColon);
    return [new FromQueryExpression(txt), afterTxt];
  }

  if (tok.s.toUpperCase() === 'SUBJECT') {
    const afterColon = consumeExpectedToken(afterTok, ':');
    const [txt, afterTxt] = parseText(afterColon);
    return [new SubjectQueryExpression(txt), afterTxt];
  }

  if (tok.s.toUpperCase() === 'IS') {
    const result = parseIsQuery(afterTok);
    if (result !== null) {
      return result;
    }
  }

  if (tok.s.toUpperCase() === 'HAS') {
    const result = parseHasQuery(afterTok);
    if (result !== null) {
      return result;
    }
  }

  if (tok.s.toUpperCase() === 'IN') {
    const afterColon = consumeExpectedToken(afterTok, ':');
    const [txt, afterTxt] = parseText(afterColon);
    return [new InQueryExpression(txt), afterTxt];
  }

  const [txt, afterTxt] = parseText(text);
  return [new GenericQueryExpression(txt), afterTxt];
};

const parseOrQuery = (text) => {
  const [lhs, afterLhs] = parseSimpleQuery(text);
  const [tok, afterOr] = nextToken(afterLhs);
  if (tok === null) {
    return [lhs, afterLhs];
  }
  if (tok.s.toUpperCase() !== 'OR') {
    return [lhs, afterLhs];
  }
  const [rhs, afterRhs] = parseOrQuery(afterOr);
  return [new OrQueryExpression(lhs, rhs), afterRhs];
};

const parseAndQuery = (text) => {
  const [lhs, afterLhs] = parseOrQuery(text);
  const [tok, afterAnd] = nextToken(afterLhs);
  if (tok === null) {
    return [lhs, afterLhs];
  }
  if (tok.s.toUpperCase() !== 'AND') {
    return [lhs, afterLhs];
  }
  const [rhs, afterRhs] = parseAndQuery(afterAnd);
  return [new AndQueryExpression(lhs, rhs), afterRhs];
};

parseQuery = (text) => {
  return parseAndQuery(text);
}

const parseQueryWrapper = (text) => {
  let currText = text;
  const exps = [];
  while (currText.length > 0) {
    const [result, leftover] = parseQuery(currText);
    if (result === null) {
      break;
    }
    exps.push(result);
    currText = leftover;
  }

  if (exps.length === 0) {
    throw new Error('Unable to parse query');
  }

  let result = null;
  for (let i = exps.length - 1; i >= 0; --i) {
    if (result === null) {
      result = exps[i];
    } else {
      result = new AndQueryExpression(exps[i], result);
    }
  }
  return result;
};

export default class SearchQueryParser {
  static parse(query) {
    return parseQueryWrapper(query);
  }
}
