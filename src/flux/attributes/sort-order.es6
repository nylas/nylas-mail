/*
Public: Represents a particular sort direction on a particular column. You should not
instantiate SortOrders manually. Instead, call {Attribute::ascending} or
{Attribute::descending} to obtain a sort order instance:

```coffee
DatabaseStore.findBy(Message)
  .where({threadId: threadId, draft: false})
  .order(Message.attributes.date.descending()).then (messages) ->

```

Section: Database
*/
export default class SortOrder {
  constructor(attr, direction = 'DESC') {
    this.attr = attr;
    this.direction = direction;
  }

  orderBySQL(klass) {
    return `\`${klass.name}\`.\`${this.attr.jsonKey}\` ${this.direction}`;
  }

  attribute() {
    return this.attr;
  }
}
