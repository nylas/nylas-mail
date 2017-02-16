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
  fromColumn(val) {
    return (val === 1) || false;
  }
  columnSQL() {
    const defaultValue = this.defaultValue ? 1 : 0;
    return `${this.jsonKey} INTEGER DEFAULT ${defaultValue}`;
  }
}
