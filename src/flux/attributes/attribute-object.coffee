Attribute = require './attribute'
Matcher = require './matcher'

###
Public: An object that can be cast to `itemClass`
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
      return new @itemClass(val)
    else
      return val ? ""

module.exports = AttributeObject
