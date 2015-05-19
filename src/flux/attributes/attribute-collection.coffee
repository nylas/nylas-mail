_ = require 'underscore'
{tableNameForJoin} = require '../models/utils'
Attribute = require './attribute'
Matcher = require './matcher'

###
Public: Collection attributes provide basic support for one-to-many relationships.
For example, Threads in N1 have a collection of Tags.

When Collection attributes are marked as `queryable`, the DatabaseStore
automatically creates a join table and maintains it as you create, save,
and delete models. When you call `persistModel`, entries are added to the
join table associating the ID of the model with the IDs of models in the
collection.

Collection attributes have an additional clause builder, `contains`:

```coffee
DatabaseStore.findAll(Thread).where([Thread.attributes.tags.contains('inbox')])
```

This is equivalent to writing the following SQL:

```sql
SELECT `Thread`.`data` FROM `Thread`
INNER JOIN `Thread-Tag` AS `M1` ON `M1`.`id` = `Thread`.`id`
WHERE `M1`.`value` = 'inbox'
ORDER BY `Thread`.`last_message_timestamp` DESC
```

The value of this attribute is always an array of ff other model objects. To use
a Collection attribute, the JSON for the parent object must contain the nested
objects, complete with their `object` field.

Section: Database
###
class AttributeCollection extends Attribute
  constructor: ({modelKey, jsonKey, itemClass}) ->
    super
    @itemClass = itemClass
    @

  toJSON: (vals) ->
    return [] unless vals
    json = []
    for val in vals
      unless val instanceof @itemClass
        msg = "AttributeCollection.toJSON: Value `#{val}` in #{@modelKey} is not an #{@itemClass.name}"
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
      obj = new @itemClass(objJSON)
      # Important: if no ids are in the JSON, don't make them up randomly.
      # This causes an object to be "different" each time it's de-serialized
      # even if it's actually the same, makes React components re-render!
      obj.id = undefined
      obj.fromJSON(objJSON) if obj.fromJSON?
      objs.push(obj)
    objs

  # Public: Returns a {Matcher} for objects containing the provided value.
  contains: (val) ->
    throw (new Error "this field cannot be queried against.") unless @queryable
    new Matcher(@, 'contains', val)

module.exports = AttributeCollection
