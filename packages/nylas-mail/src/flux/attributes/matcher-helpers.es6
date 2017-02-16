import {
  SearchQueryExpressionVisitor,
  OrQueryExpression,
  AndQueryExpression,
  UnreadStatusQueryExpression,
  StarredStatusQueryExpression,
  MatchQueryExpression,
} from '../models/thread-query-ast'

/*
 * This class visits a match-compatible subtree and condenses it into a single
 * MatchQueryExpression.
 */
class MatchQueryExpressionVisitor extends SearchQueryExpressionVisitor {
  visit(root) {
    const result = this.visitAndGetResult(root);
    return new MatchQueryExpression(`${result}`);
  }

  _assertIsMatchCompatible(node) {
    if (!node.isMatchCompatible()) {
      throw new Error(`Expected ${node} to be match compatible`);
    }
  }

  visitAnd(node) {
    this._assertIsMatchCompatible(node);
    const lhs = this.visitAndGetResult(node.e1);
    const rhs = this.visitAndGetResult(node.e2);
    this._result = `(${lhs} AND ${rhs})`;
  }

  visitOr(node) {
    const lhs = this.visitAndGetResult(node.e1);
    const rhs = this.visitAndGetResult(node.e2);
    this._result = `(${lhs} OR ${rhs})`;
  }

  visitFrom(node) {
    const text = this.visitAndGetResult(node.text);
    this._result = `(from_ : "${text}"*)`;
  }

  visitTo(node) {
    const text = this.visitAndGetResult(node.text);
    this._result = `(to_ : "${text}"*)`;
  }

  visitSubject(node) {
    const text = this.visitAndGetResult(node.text);
    this._result = `(subject : "${text}"*)`;
  }

  visitGeneric(node) {
    const text = this.visitAndGetResult(node.text);
    this._result = `("${text}"*)`
  }

  visitText(node) {
    // TODO: Should we do anything about possible SQL injection attacks?
    this._result = node.token.s;
  }

  visitUnread(node) {
    this._assertIsMatchCompatible(node);
  }

  visitStarred(node) {
    this._assertIsMatchCompatible(node);
  }

  visitIn(node) {
    const text = this.visitAndGetResult(node.text);
    this._result = `(categories : "${text}*")`;
  }
}

/*
 * This class creates a new AST by converting match-compatible subtrees into
 * MatchQueryExpressions.
 */
class MatchCompatibleQueryCondenser extends SearchQueryExpressionVisitor {
  constructor() {
    super();
    this._matchVisitor = new MatchQueryExpressionVisitor();
  }

  visit(root) {
    return this.visitAndGetResult(root);
  }

  visitAnd(node) {
    if (node.isMatchCompatible()) {
      this._result = this._matchVisitor.visit(node);
      return;
    }

    const lhs = this.visitAndGetResult(node.e1);
    const rhs = this.visitAndGetResult(node.e2);
    this._result = new AndQueryExpression(lhs, rhs);
  }

  visitOr(node) {
    if (node.isMatchCompatible()) {
      this._result = this._matchVisitor.visit(node);
      return;
    }

    const lhs = this.visitAndGetResult(node.e1);
    const rhs = this.visitAndGetResult(node.e2);
    this._result = new OrQueryExpression(lhs, rhs);
  }

  visitFrom(node) {
    this._result = this._matchVisitor.visit(node);
  }

  visitTo(node) {
    this._result = this._matchVisitor.visit(node);
  }

  visitSubject(node) {
    this._result = this._matchVisitor.visit(node);
  }

  visitGeneric(node) {
    this._result = this._matchVisitor.visit(node);
  }

  visitText(node) {
    this._result = this._matchVisitor.visit(node);
  }

  visitIn(node) {
    this._result = this._matchVisitor.visit(node);
  }

  visitUnread(node) {
    this._result = new UnreadStatusQueryExpression(node.status);
  }

  visitStarred(node) {
    this._result = new StarredStatusQueryExpression(node.status);
  }
}

/*
 * Converts a search query into the appropriate where clause. It does this by
 * converting match-compatible subtrees into the appropriate subquery that
 * uses a MATCH clause.
 */
export class StructuredSearchQueryVisitor extends SearchQueryExpressionVisitor {
  constructor(className) {
    super();
    this._className = className;
  }

  visit(root) {
    const condenser = new MatchCompatibleQueryCondenser();
    return this.visitAndGetResult(condenser.visit(root));
  }

  visitAnd(node) {
    const lhs = this.visitAndGetResult(node.e1);
    const rhs = this.visitAndGetResult(node.e2);
    this._result = `(${lhs} AND ${rhs})`;
  }

  visitOr(node) {
    const lhs = this.visitAndGetResult(node.e1);
    const rhs = this.visitAndGetResult(node.e2);
    this._result = `(${lhs} OR ${rhs})`;
  }

  visitFrom(node) {
    throw new Error('Unreachable', node);
  }

  visitTo(node) {
    throw new Error('Unreachable', node);
  }

  visitSubject(node) {
    throw new Error('Unreachable', node);
  }

  visitGeneric(node) {
    throw new Error('Unreachable', node);
  }

  visitText(node) {
    throw new Error('Unreachable', node);
  }

  visitIn(node) {
    throw new Error('Unreachable', node);
  }

  visitUnread(node) {
    const unread = node.status ? 1 : 0;
    this._result = `(\`${this._className}\`.\`unread\` = ${unread})`;
  }

  visitStarred(node) {
    const starred = node.status ? 1 : 0;
    this._result = `(\`${this._className}\`.\`starred\` = ${starred})`;
  }

  visitMatch(node) {
    const searchTable = `${this._className}Search`;
    this._result = `(\`${this._className}\`.\`id\` IN (SELECT \`content_id\` FROM \`${searchTable}\` WHERE \`${searchTable}\` MATCH '${node.rawQuery}' LIMIT 1000))`;
  }
}

