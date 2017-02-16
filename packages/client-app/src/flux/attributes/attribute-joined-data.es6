import Attribute from './attribute';

const NullPlaceholder = "!NULLVALUE!";

/*
Public: Joined Data attributes allow you to store certain attributes of an
object in a separate table in the database. We use this attribute
type for Message bodies. Storing message bodies, which can be very
large, in a separate table allows us to make queries on message
metadata extremely fast, and inflate Message objects without their
bodies to build the thread list.

When building a query on a model with a JoinedData attribute, you need
to call `include` to explicitly load the joined data attribute.
The query builder will automatically perform a `LEFT OUTER JOIN` with
the secondary table to retrieve the attribute:

```coffee
DatabaseStore.find(Message, '123').then (message) ->
  // message.body is undefined

DatabaseStore.find(Message, '123').include(Message.attributes.body).then (message) ->
  // message.body is defined
```

When you call `persistModel`, JoinedData attributes are automatically
written to the secondary table.

JoinedData attributes cannot be `queryable`.

Section: Database
*/
export default class AttributeJoinedData extends Attribute {
  static NullPlaceholder = NullPlaceholder;

  constructor({modelKey, jsonKey, modelTable, queryable}) {
    super({modelKey, jsonKey, queryable});
    this.modelTable = modelTable;
  }

  toJSON(val) {
    return val;
  }

  fromJSON(val) {
    return (val === null || val === undefined || val === false) ? null : `${val}`;
  }

  selectSQL() {
    // NullPlaceholder is necessary because if the LEFT JOIN returns nothing, it leaves the field
    // blank, and it comes through in the result row as "" rather than NULL
    return `IFNULL(\`${this.modelTable}\`.\`value\`, '${NullPlaceholder}') AS \`${this.modelKey}\``;
  }

  includeSQL(klass) {
    return `LEFT OUTER JOIN \`${this.modelTable}\` ON \`${this.modelTable}\`.\`id\` = \`${klass.name}\`.\`id\``;
  }
}
