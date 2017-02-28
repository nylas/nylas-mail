
class SearchQueryExpressionVisitor {
  constructor() {
    this._result = null;
  }

  visitAndGetResult(node) {
    node.accept(this);
    const result = this._result;
    this._result = null;
    return result;
  }

  visitAnd(node) { throw new Error('Abstract function not implemented!', node); }
  visitOr(node) { throw new Error('Abstract function not implemented!', node); }
  visitFrom(node) { throw new Error('Abstract function not implemented!', node); }
  visitTo(node) { throw new Error('Abstract function not implemented!', node); }
  visitSubject(node) { throw new Error('Abstract function not implemented!', node); }
  visitGeneric(node) { throw new Error('Abstract function not implemented!', node); }
  visitText(node) { throw new Error('Abstract function not implemented!', node); }
  visitUnread(node) { throw new Error('Abstract function not implemented!', node); }
  visitStarred(node) { throw new Error('Abstract function not implemented!', node); }
  visitMatch(node) { throw new Error('Abstract function not implemented!', node); }
  visitIn(node) { throw new Error('Abstract function not implemented!', node); }
}

class QueryExpression {
  constructor() {
    this._isMatchCompatible = null;
  }

  accept(visitor) {
    throw new Error('Abstract function not implemented!', visitor);
  }

  isMatchCompatible() {
    if (this._isMatchCompatible === null) {
      this._isMatchCompatible = this._computeIsMatchCompatible();
    }
    return this._isMatchCompatible;
  }

  _computeIsMatchCompatible() {
    throw new Error('Abstract function not implemented!');
  }

  equals(other) {
    throw new Error('Abstract function not implemented!', other);
  }
}

class AndQueryExpression extends QueryExpression {
  constructor(e1, e2) {
    super();
    this.e1 = e1;
    this.e2 = e2;
  }

  accept(visitor) {
    visitor.visitAnd(this);
  }

  _computeIsMatchCompatible() {
    return this.e1.isMatchCompatible() && this.e2.isMatchCompatible();
  }

  equals(other) {
    if (!(other instanceof AndQueryExpression)) {
      return false;
    }
    return this.e1.equals(other.e1) && this.e2.equals(other.e2);
  }
}

class OrQueryExpression extends QueryExpression {
  constructor(e1, e2) {
    super();
    this.e1 = e1;
    this.e2 = e2;
  }

  accept(visitor) {
    visitor.visitOr(this);
  }

  _computeIsMatchCompatible() {
    return this.e1.isMatchCompatible() && this.e2.isMatchCompatible();
  }

  equals(other) {
    if (!(other instanceof OrQueryExpression)) {
      return false;
    }
    return this.e1.equals(other.e1) && this.e2.equals(other.e2);
  }
}

class FromQueryExpression extends QueryExpression {
  constructor(text) {
    super();
    this.text = text;
  }

  accept(visitor) {
    visitor.visitFrom(this);
  }

  _computeIsMatchCompatible() {
    return true;
  }

  equals(other) {
    if (!(other instanceof FromQueryExpression)) {
      return false;
    }
    return this.text.equals(other.text);
  }
}

class ToQueryExpression extends QueryExpression {
  constructor(text) {
    super();
    this.text = text;
  }

  accept(visitor) {
    visitor.visitTo(this);
  }

  _computeIsMatchCompatible() {
    return true;
  }

  equals(other) {
    if (!(other instanceof ToQueryExpression)) {
      return false;
    }
    return this.text.equals(other.text);
  }
}

class SubjectQueryExpression extends QueryExpression {
  constructor(text) {
    super();
    this.text = text;
  }

  accept(visitor) {
    visitor.visitSubject(this);
  }

  _computeIsMatchCompatible() {
    return true;
  }

  equals(other) {
    if (!(other instanceof SubjectQueryExpression)) {
      return false;
    }
    return this.text.equals(other.text);
  }
}

class UnreadStatusQueryExpression extends QueryExpression {
  constructor(status) {
    super();
    this.status = status;
  }


  accept(visitor) {
    visitor.visitUnread(this);
  }

  _computeIsMatchCompatible() {
    return false;
  }

  equals(other) {
    if (!(other instanceof UnreadStatusQueryExpression)) {
      return false;
    }
    return this.status === other.status;
  }
}

class StarredStatusQueryExpression extends QueryExpression {
  constructor(status) {
    super();
    this.status = status;
  }

  accept(visitor) {
    visitor.visitStarred(this);
  }

  _computeIsMatchCompatible() {
    return false;
  }

  equals(other) {
    if (!(other instanceof StarredStatusQueryExpression)) {
      return false;
    }
    return this.status === other.status;
  }
}

class GenericQueryExpression extends QueryExpression {
  constructor(text) {
    super();
    this.text = text;
  }

  accept(visitor) {
    visitor.visitGeneric(this);
  }

  _computeIsMatchCompatible() {
    return true;
  }

  equals(other) {
    if (!(other instanceof GenericQueryExpression)) {
      return false;
    }
    return this.text.equals(other.text);
  }
}

class TextQueryExpression extends QueryExpression {
  constructor(text) {
    super();
    this.token = text;
  }

  accept(visitor) {
    visitor.visitText(this);
  }

  _computeIsMatchCompatible() {
    return true;
  }

  equals(other) {
    if (!(other instanceof TextQueryExpression)) {
      return false;
    }
    return this.token.equals(other.token);
  }
}

class InQueryExpression extends QueryExpression {
  constructor(text) {
    super();
    this.text = text;
  }

  accept(visitor) {
    visitor.visitIn(this);
  }

  _computeIsMatchCompatible() {
    return true;
  }

  equals(other) {
    if (!(other instanceof InQueryExpression)) {
      return false;
    }
    return this.text.equals(other.text);
  }
}

/*
 * Intermediate representation for multiple match-compatible nodes. Used when
 * translating the initial query AST into the proper SQL-compatible query.
 */
class MatchQueryExpression extends QueryExpression {
  constructor(rawMatchQuery) {
    super();
    this.rawQuery = rawMatchQuery;
  }

  accept(visitor) {
    visitor.visitMatch(this);
  }

  _computeIsMatchCompatible() {
    /*
     * We should never call this for match nodes b/c we generate match nodes
     * after checking if other nodes are match-compatible.
     */
    throw new Error('Invalid node');
  }

  equals(other) {
    if (!(other instanceof MatchQueryExpression)) {
      return false;
    }
    return this.rawQuery === other.rawQuery;
  }
}

class SearchQueryToken {
  constructor(s) {
    this.s = s;
  }

  equals(other) {
    if (!(other instanceof SearchQueryToken)) {
      return false;
    }
    return this.s === other.s;
  }
}

module.exports = {
  SearchQueryExpressionVisitor,
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
  MatchQueryExpression,
  InQueryExpression,
};
