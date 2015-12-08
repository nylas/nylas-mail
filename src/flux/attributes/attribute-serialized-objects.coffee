Utils = require '../models/utils'
Attribute = require './attribute'

###
Public: An object that is a composite of several types of objects. We
inflate and deflate them using `Utils.deserializeRegisteredObjects` and
`Utils.serializeRegisteredObjects`.

If you're storing an object of a single type, use `AttributeObject` with
the `itemClass` option

Section: Database
###
class AttributeSerializedObjects extends Attribute
  toJSON: (val) ->
    return Utils.serializeRegisteredObjects(val)

  fromJSON: (val) ->
    return Utils.deserializeRegisteredObjects(val)

module.exports = AttributeSerializedObjects
