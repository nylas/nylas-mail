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
ORDER BY `Thread`.`lastMessageReceivedTimestamp` DESC
```

The value of this attribute is always an array of other model objects.

Section: Database
*/
export default class AttributeCollection extends Attribute {
  constructor({modelKey, jsonKey, itemClass, joinOnField, joinQueryableBy, queryable}) {
    super({modelKey, jsonKey, queryable});
    this.itemClass = itemClass;
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

    return vals.map((val) => {
      if (this.itemClass && !(val instanceof this.itemClass)) {
        throw new Error(`AttributeCollection::toJSON: Value \`${val}\` in ${this.modelKey} is not an ${this.itemClass.name}`);
      }
      return (val.toJSON !== undefined) ? val.toJSON() : val;
    });
  }

  fromJSON(json) {
    const Klass = this.itemClass;

    if (!json || !(json instanceof Array)) {
      return [];
    }
    return json.map((objJSON) => {
      if (!objJSON || !Klass || objJSON instanceof Klass) {
        return objJSON;
      }
      return new Klass(objJSON);
    });
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
