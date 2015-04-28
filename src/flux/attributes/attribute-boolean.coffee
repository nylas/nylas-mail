_ = require 'underscore-plus'
{tableNameForJoin} = require '../models/utils'
Attribute = require './attribute'

###
Public: The value of this attribute is always a boolean. Null values are coerced to false.

String attributes can be queries using `equal` and `not`. Matching on
`greaterThan` and `lessThan` is not supported.
###
class AttributeBoolean extends Attribute
  toJSON: (val) -> val
  fromJSON: (val) -> (val is 'true' or val is true) || false
  columnSQL: -> "#{@jsonKey} INTEGER"

module.exports = AttributeBoolean