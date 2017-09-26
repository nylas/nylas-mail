import Attribute from './attribute';
import Utils from '../models/utils';

/*
Public: An object that can be cast to `itemClass`
Section: Database
*/
export default class AttributeObject extends Attribute {
  constructor({ modelKey, jsonKey, itemClass, queryable }) {
    super({ modelKey, jsonKey, queryable });
    this.itemClass = itemClass;
  }

  toJSON(val) {
    return val && val.toJSON ? val.toJSON() : val;
  }

  fromJSON(val) {
    const Klass = this.itemClass;
    if (!val || (Klass && val instanceof Klass)) {
      return val;
    }
    if (Klass) {
      return new Klass(val);
    }
    if (val.__cls) {
      return Utils.convertToModel(val);
    }
    return val;
  }
}
