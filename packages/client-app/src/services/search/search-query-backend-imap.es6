import {
  AndQueryExpression,
  SearchQueryExpressionVisitor,
} from './search-query-ast';

class IMAPSearchQueryExpressionVisitor extends SearchQueryExpressionVisitor {
  visit(root) {
    const result = this.visitAndGetResult(root);
    if (root instanceof AndQueryExpression) {
      return result;
    }
    return [result];
  }

  visitAnd(node) {
    const lhs = this.visitAndGetResult(node.e1);
    const rhs = this.visitAndGetResult(node.e2);
    this._result = [];
    if (node.e1 instanceof AndQueryExpression) {
      this._result = this._result.concat(lhs);
    } else {
      this._result.push(lhs);
    }

    if (node.e2 instanceof AndQueryExpression) {
      this._result = this._result.concat(rhs);
    } else {
      this._result.push(rhs);
    }
  }

  visitOr(node) {
    const lhs = this.visitAndGetResult(node.e1);
    const rhs = this.visitAndGetResult(node.e2);
    this._result = ['OR', lhs, rhs];
  }

  visitFrom(node) {
    const text = this.visitAndGetResult(node.text);
    this._result = ['FROM', text];
  }

  visitTo(node) {
    const text = this.visitAndGetResult(node.text);
    this._result = ['TO', text];
  }

  visitSubject(node) {
    const text = this.visitAndGetResult(node.text);
    this._result = ['SUBJECT', text];
  }

  visitGeneric(node) {
    const text = this.visitAndGetResult(node.text);
    this._result = ['TEXT', text];
  }

  visitText(node) {
    this._result = node.token.s;
  }

  visitUnread(node) {
    this._result = node.status ? 'UNSEEN' : 'SEEN';
  }

  visitStarred(node) {
    this._result = node.status ? 'FLAGGED' : 'UNFLAGGED';
  }

  visitIn(/* node */) {
    // TODO: Somehow make the search switch folders. To make this work correctly
    // with nested expressions we would probably end up generating a mini
    // program that would instruct the connection to switch to a folder and issue
    // the proper search command for that subquery. At the end we would combine
    // the results according to the query.
    this._result = 'ALL';
  }
}

export default class IMAPSearchQueryBackend {
  static compile(ast) {
    return (new IMAPSearchQueryBackend()).compile(ast);
  }

  compile(ast) {
    return (new IMAPSearchQueryExpressionVisitor()).visit(ast);
  }
}
