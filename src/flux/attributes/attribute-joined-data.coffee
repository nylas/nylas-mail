_ = require 'underscore-plus'
{tableNameForJoin} = require '../models/utils'
Attribute = require './attribute'

NullPlaceholder = "!NULLVALUE!"

###
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

```
DatabaseStore.find(Message, '123').then (message) ->
  # message.body is undefined

DatabaseStore.find(Message, '123').include(Message.attributes.body).then (message) ->
  # message.body is defined
```

When you call `persistModel`, JoinedData attributes are automatically
written to the secondary table.

JoinedData attributes cannot be `queryable`.
###
class AttributeJoinedData extends Attribute
  constructor: ({modelKey, jsonKey, modelTable}) ->
    super
    @modelTable = modelTable
    @

  selectSQL: (klass) ->
    # NullPlaceholder is necessary because if the LEFT JOIN returns nothing, it leaves the field
    # blank, and it comes through in the result row as "" rather than NULL
    "IFNULL(`#{@modelTable}`.`value`, '#{NullPlaceholder}') AS `#{@modelKey}`"

  includeSQL: (klass) ->
    "LEFT OUTER JOIN `#{@modelTable}` ON `#{@modelTable}`.`id` = `#{klass.name}`.`id`"


module.exports = AttributeJoinedData