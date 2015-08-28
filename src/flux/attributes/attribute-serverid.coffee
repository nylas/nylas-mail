AttributeString = require './attribute-string'
Matcher = require './matcher'

###
Public: The value of this attribute is always a string or `null`.

String attributes can be queries using `equal`, `not`, and `startsWith`. Matching on
`greaterThan` and `lessThan` is not supported.

Section: Database
###
class AttributeServerId extends AttributeString
  toJSON: (val) ->
    if val and Utils.isTempId(val)
      throw (new Error "AttributeServerId::toJSON (#{@modelKey}) #{val} does not look like a valid server id")

  equal: (val) ->
    if val and Utils.isTempId(val)
      throw (new Error "AttributeServerId::equal (#{@modelKey}) #{val} is not a valid value for this field.")
    super

module.exports = AttributeString
