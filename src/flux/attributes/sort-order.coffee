###
Public: Represents a particular sort direction on a particular column. You should not
instantiate SortOrders manually. Instead, call {Attribute::ascending} or
{Attribute::descending} to obtain a sort order instance:

```coffee
DatabaseStore.findBy(Message)
  .where({threadId: threadId, draft: false})
  .order(Message.attributes.date.descending()).then (messages) ->

```

Section: Database
###
class SortOrder
  constructor: (@attr, @direction = 'DESC') ->
  orderBySQL: (klass) ->
    "`#{klass.name}`.`#{@attr.jsonKey}` #{@direction}"
  attribute: ->
    @attr

module.exports = SortOrder
