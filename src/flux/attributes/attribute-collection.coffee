_ = require 'underscore'
{tableNameForJoin} = require '../models/utils'
Attribute = require './attribute'
Matcher = require './matcher'

###
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
###
class AttributeCollection extends Attribute
  constructor: ({modelKey, jsonKey, itemClass, joinOnField}) ->
    super
    @itemClass = itemClass
    @joinOnField = joinOnField
    @

  toJSON: (vals) ->
    return [] unless vals
    json = []
    for val in vals
      unless val instanceof @itemClass
        msg = "AttributeCollection::toJSON: Value `#{val}` in #{@modelKey} is not an #{@itemClass.name}"
        throw new Error msg
      if val.toJSON?
        json.push(val.toJSON())
      else
        json.push(val)
    json

  fromJSON: (json) ->
    return [] unless json && json instanceof Array
    objs = []
    for objJSON in json
      if @itemClass.prototype.fromJSON?
        obj = new @itemClass
        # Important: if no ids are in the JSON, don't make them up
        # randomly.  This causes an object to be "different" each time it's
        # de-serialized even if it's actually the same, makes React
        # components re-render!
        obj.clientId = undefined
        obj.fromJSON(objJSON)
      else
        obj = new @itemClass(objJSON)
        obj.clientId = undefined
      objs.push(obj)
    objs

  # Public: Returns a {Matcher} for objects containing the provided value.
  contains: (val) ->
    throw (new Error "AttributeCollection::contains (#{@modelKey}) - you must provide a value") unless val?
    throw (new Error "AttributeCollection::contains (#{@modelKey}) - this field cannot be queried against.") unless @queryable
    new Matcher(@, 'contains', val)

  containsAny: (vals) ->
    throw (new Error "AttributeCollection::contains (#{@modelKey}) - you must provide a value") unless vals?
    throw (new Error "AttributeCollection::contains (#{@modelKey}) - this field cannot be queried against.") unless @queryable
    new Matcher(@, 'containsAny', vals)

module.exports = AttributeCollection
