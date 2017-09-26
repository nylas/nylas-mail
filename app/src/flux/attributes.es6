import Matcher from './attributes/matcher';
import SortOrder from './attributes/sort-order';
import AttributeNumber from './attributes/attribute-number';
import AttributeString from './attributes/attribute-string';
import AttributeObject from './attributes/attribute-object';
import AttributeBoolean from './attributes/attribute-boolean';
import AttributeDateTime from './attributes/attribute-datetime';
import AttributeCollection from './attributes/attribute-collection';
import AttributeJoinedData from './attributes/attribute-joined-data';

export default {
  Matcher: Matcher,
  SortOrder: SortOrder,

  Number: (...args) => new AttributeNumber(...args),
  String: (...args) => new AttributeString(...args),
  Object: (...args) => new AttributeObject(...args),
  Boolean: (...args) => new AttributeBoolean(...args),
  DateTime: (...args) => new AttributeDateTime(...args),
  Collection: (...args) => new AttributeCollection(...args),
  JoinedData: (...args) => new AttributeJoinedData(...args),

  AttributeNumber: AttributeNumber,
  AttributeString: AttributeString,
  AttributeObject: AttributeObject,
  AttributeBoolean: AttributeBoolean,
  AttributeDateTime: AttributeDateTime,
  AttributeCollection: AttributeCollection,
  AttributeJoinedData: AttributeJoinedData,
};
