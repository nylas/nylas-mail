Attribute = require './attribute'
Matcher = require './matcher'

###
Public: An object that can be cast to `itemClass`

If you don't know the `itemClass` ahead of time and are storing complex,
typed, nested objects, use `AttributeSerializedObject` instead.

Section: Database
###
class AttributeObject extends Attribute
  constructor: ({modelKey, jsonKey, itemClass}) ->
    super
    @itemClass = itemClass
    @

  toJSON: (val) ->
    if val?.toJSON?
      return val.toJSON()
    else
      return val

  fromJSON: (val) ->
    if @itemClass
      obj = new @itemClass(val)
      # Important: if no ids are in the JSON, don't make them up randomly.
      # This causes an object to be "different" each time it's
      # de-serialized even if it's actually the same, makes React
      # components re-render!
      obj.clientId = undefined
      # Warning: typeof(null) is object
      if obj.fromJSON and val and typeof(val) is 'object'
        obj.fromJSON(val)
      return obj
    else
      return val ? ""

module.exports = AttributeObject
