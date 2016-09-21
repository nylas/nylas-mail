import Attribute from './attribute';

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
    return ((val === 'true') || (val === true)) || false;
  }
  columnSQL() {
    return `${this.jsonKey} INTEGER`;
  }
}
