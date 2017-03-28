import _ from 'underscore'
import {
  AndQueryExpression,
  SearchQueryExpressionVisitor,
} from './search-query-ast';

const TOP = 'top';

class IMAPSearchQueryFolderFinderVisitor extends SearchQueryExpressionVisitor {
  visit(root) {
    const result = this.visitAndGetResult(root);
    if (result === TOP) {
      return 'all';
    }
    return result;
  }

  visitAnd(node) {
    const lhs = this.visitAndGetResult(node.e1);
    const rhs = this.visitAndGetResult(node.e2);
    if (lhs === TOP) {
      this._result = rhs;
      return;
    }
    if (rhs === TOP) {
      this._result = lhs;
      return;
    }
    this._result = _.intersection(lhs, rhs);
  }

  visitOr(node) {
    const lhs = this.visitAndGetResult(node.e1);
    const rhs = this.visitAndGetResult(node.e2);
    if (lhs === TOP || rhs === TOP) {
      this._result = TOP;
      return;
    }
    this._result = _.union(lhs, rhs);
  }

  visitIn(node) {
    const folderName = this.visitAndGetResult(node.text);
    this._result = [folderName];
  }

  visitFrom(/* node */) {
    this._result = TOP;
  }

  visitTo(/* node */) {
    this._result = TOP;
  }

  visitSubject(/* node */) {
    this._result = TOP;
  }

  visitGeneric(/* node */) {
    this._result = TOP;
  }

  visitText(node) {
    this._result = node.token.s;
  }

  visitUnread(/* node */) {
    this._result = TOP;
  }

  visitStarred(/* node */) {
    this._result = TOP;
  }
}

class IMAPSearchQueryExpressionVisitor extends SearchQueryExpressionVisitor {
  constructor(folder) {
    super();
    this._folder = folder;
  }

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

  visitIn(node) {
    const text = this.visitAndGetResult(node.text);
    this._result = text === this._folder.name ? 'ALL' : '!ALL';
  }
}


export default class IMAPSearchQueryBackend {
  static ALL_FOLDERS() {
    return 'all';
  }

  static compile(ast, folder) {
    return (new IMAPSearchQueryBackend()).compile(ast, folder);
  }

  static folderNamesForQuery(ast) {
    return (new IMAPSearchQueryFolderFinderVisitor()).visit(ast);
  }

  compile(ast, folder) {
    return (new IMAPSearchQueryExpressionVisitor(folder)).visit(ast);
  }
}
