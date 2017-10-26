import Attribute from './attribute';
import Matcher from './matcher';
/*
Public: The value of this attribute is always a boolean. Null values are coerced to false.

String attributes can be queries using `equal` and `not`. Matching on
`greaterThan` and `lessThan` is not supported.

Section: Database
*/
export default class AttributeBoolean extends Attribute {
  toJSON(val) {
    return val;
  }
  fromJSON(val) {
    // Some attributes we identify as booleans in Mailspring are ints
    // in the underlying sync engine for reference-counting purposes.
    // Coerce all values > 0 to `true`.
    return val === 'true' || val / 1 >= 1 || val === true || false;
  }
  fromColumn(val) {
    return val >= 1 || false;
  }
  columnSQL() {
    const defaultValue = this.defaultValue ? 1 : 0;
    return `${this.tableColumn} INTEGER DEFAULT ${defaultValue}`;
  }
  equal(val) {
    // equal(true) matches all values != 0
    this._assertPresentAndQueryable('equal', val);
    return new Matcher(this, val ? '!=' : '=', 0);
  }
}
