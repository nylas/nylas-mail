import Attribute from './attribute';
import Matcher from './matcher';

/*
Public: Collection attributes provide basic support for one-to-many relationships.
For example, Threads in N1 have a collection of Labels or Folders.

When Collection attributes are marked as `queryable`, the DatabaseStore
automatically creates a join table and maintains it as you create, save,
and delete models. When you call `persistModel`, entries are added to the
join table associating the ID of the model with the IDs of models in the collection.

Collection attributes have an additional clause builder, `contains`:

```coffee
DatabaseStore.findAll(Thread).where([Thread.attributes.categories.contains('inbox')])
```

This is equivalent to writing the following SQL:

```sql
SELECT `Thread`.`data` FROM `Thread`
INNER JOIN `ThreadLabel` AS `M1` ON `M1`.`id` = `Thread`.`id`
WHERE `M1`.`value` = 'inbox'
ORDER BY `Thread`.`last_message_received_timestamp` DESC
```

The value of this attribute is always an array of other model objects.

Section: Database
*/
export default class AttributeCollection extends Attribute {
  constructor({modelKey, jsonKey, itemClass, joinOnField, joinQueryableBy, queryable}) {
    super({modelKey, jsonKey, queryable});
    this.ItemClass = this.itemClass = itemClass;
    this.joinOnField = joinOnField;
    this.joinQueryableBy = joinQueryableBy || [];
  }

  toJSON(vals) {
    if (!vals) {
      return [];
    }

    if (!(vals instanceof Array)) {
      throw new Error(`AttributeCollection::toJSON: ${this.modelKey} is not an array.`);
    }

    const json = []
    for (const val of vals) {
      if (!(val instanceof this.ItemClass)) {
        throw new Error(`AttributeCollection::toJSON: Value \`${val}\` in ${this.modelKey} is not an ${this.ItemClass.name}`);
      }
      if (val.toJSON !== undefined) {
        json.push(val.toJSON());
      } else {
        json.push(val);
      }
    }
    return json;
  }

  fromJSON(json) {
    if (!json || !(json instanceof Array)) {
      return [];
    }
    const objs = [];

    for (const objJSON of json) {
      // Note: It's possible for a malformed API request to return an array
      // of null values. N1 is tolerant to this type of error, but shouldn't
      // happen on the API end.
      if (!objJSON) {
        continue;
      }

      if (this.ItemClass.prototype.fromJSON) {
        const obj = new this.ItemClass();
        // Important: if no ids are in the JSON, don't make them up
        // randomly.  This causes an object to be "different" each time it's
        // de-serialized even if it's actually the same, makes React
        // components re-render!
        obj.clientId = undefined;
        obj.fromJSON(objJSON);
        objs.push(obj);
      } else {
        const obj = new this.ItemClass(objJSON);
        obj.clientId = undefined;
        objs.push(obj);
      }
    }
    return objs;
  }

  // Public: Returns a {Matcher} for objects containing the provided value.
  contains(val) {
    this._assertPresentAndQueryable('contains', val);
    return new Matcher(this, 'contains', val);
  }

  containsAny(vals) {
    this._assertPresentAndQueryable('contains', vals);
    return new Matcher(this, 'containsAny', vals);
  }
}
