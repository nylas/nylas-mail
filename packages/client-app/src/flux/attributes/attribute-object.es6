import Attribute from './attribute';

/*
Public: An object that can be cast to `itemClass`
Section: Database
*/
export default class AttributeObject extends Attribute {
  constructor({modelKey, jsonKey, itemClass, queryable}) {
    super({modelKey, jsonKey, queryable});
    this.ItemClass = itemClass;
  }

  toJSON(val) {
    return (val && val.toJSON) ? val.toJSON() : val;
  }

  fromJSON(val) {
    if (!this.ItemClass || val instanceof this.ItemClass) {
      return val || "";
    }
    return new this.ItemClass(val);
  }
}
