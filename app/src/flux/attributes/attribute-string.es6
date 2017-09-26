import Attribute from './attribute';
import Matcher from './matcher';

/*
Public: The value of this attribute is always a string or `null`.

String attributes can be queries using `equal`, `not`, and `startsWith`. Matching on
`greaterThan` and `lessThan` is not supported.

Section: Database
*/
export default class AttributeString extends Attribute {
  toJSON(val) {
    return val;
  }

  fromJSON(val) {
    return val === null || val === undefined || val === false ? null : `${val}`;
  }

  // Public: Returns a {Matcher} for objects starting with the provided value.
  startsWith(val) {
    return new Matcher(this, 'startsWith', val);
  }

  columnSQL() {
    return `${this.tableColumn} TEXT`;
  }

  like(val) {
    this._assertPresentAndQueryable('like', val);
    return new Matcher(this, 'like', val);
  }

  lessThan(val) {
    this._assertPresentAndQueryable('lessThanOrEqualTo', val);
    return new Matcher(this, '<', val);
  }

  lessThanOrEqualTo(val) {
    this._assertPresentAndQueryable('lessThanOrEqualTo', val);
    return new Matcher(this, '<=', val);
  }

  greaterThan(val) {
    this._assertPresentAndQueryable('greaterThanOrEqualTo', val);
    return new Matcher(this, '>', val);
  }

  greaterThanOrEqualTo(val) {
    this._assertPresentAndQueryable('greaterThanOrEqualTo', val);
    return new Matcher(this, '>=', val);
  }
}
