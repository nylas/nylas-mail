import AttributeString from './attribute-string';
import Utils from '../models/utils';

/*
Public: The value of this attribute is always a string or `null`.

String attributes can be queries using `equal`, `not`, and `startsWith`. Matching on
`greaterThan` and `lessThan` is not supported.

Section: Database
*/
export default class AttributeServerId extends AttributeString {
  toJSON(val) {
    if (val && Utils.isTempId(val)) {
      throw new Error(`AttributeServerId::toJSON (${this.modelKey}) ${val} does not look like a valid server id`);
    }
    return super.toJSON(val);
  }

  equal(val) {
    if (val && Utils.isTempId(val)) {
      throw new Error(`AttributeServerId::equal (${this.modelKey}) ${val} is not a valid value for this field.`);
    }
    return super.equal(val);
  }
}
