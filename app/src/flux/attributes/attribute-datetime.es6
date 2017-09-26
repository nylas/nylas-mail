import Attribute from './attribute';
import Matcher from './matcher';

/*
Public: The value of this attribute is always a Javascript `Date`, or `null`.

Section: Database
*/
export default class AttributeDateTime extends Attribute {
  toJSON(val) {
    if (!val) {
      return null;
    }
    if (!(val instanceof Date)) {
      throw new Error(
        `Attempting to toJSON AttributeDateTime which is not a date: ${this.modelKey} = ${val}`
      );
    }
    return val.getTime() / 1000.0;
  }

  fromJSON(val) {
    if (!val || val instanceof Date) {
      return val;
    }
    return new Date(val * 1000);
  }

  columnSQL() {
    return `${this.tableColumn} INTEGER`;
  }

  // Public: Returns a {Matcher} for objects greater than the provided value.
  greaterThan(val) {
    this._assertPresentAndQueryable('greaterThan', val);
    return new Matcher(this, '>', val);
  }

  // Public: Returns a {Matcher} for objects less than the provided value.
  lessThan(val) {
    this._assertPresentAndQueryable('lessThan', val);
    return new Matcher(this, '<', val);
  }

  // Public: Returns a {Matcher} for objects greater than the provided value.
  greaterThanOrEqualTo(val) {
    this._assertPresentAndQueryable('greaterThanOrEqualTo', val);
    return new Matcher(this, '>=', val);
  }

  // Public: Returns a {Matcher} for objects less than the provided value.
  lessThanOrEqualTo(val) {
    this._assertPresentAndQueryable('lessThanOrEqualTo', val);
    return new Matcher(this, '<=', val);
  }

  gt = AttributeDateTime.greaterThan;
  lt = AttributeDateTime.lessThan;
  gte = AttributeDateTime.greaterThanOrEqualTo;
  lte = AttributeDateTime.lessThanOrEqualTo;
}
