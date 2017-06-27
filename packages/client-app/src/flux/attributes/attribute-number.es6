import Attribute from './attribute';
import Matcher from './matcher';

/*
Public: The value of this attribute is always a number, or null.

Section: Database
*/
export default class AttributeNumber extends Attribute {
  toJSON(val) {
    return val;
  }

  fromJSON(val) {
    return isNaN(val) ? null : Number(val);
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

  gt = AttributeNumber.prototype.greaterThan;
  lt = AttributeNumber.prototype.lessThan;
  gte = AttributeNumber.prototype.greaterThanOrEqualTo;
  lte = AttributeNumber.prototype.lessThanOrEqualTo;
}
