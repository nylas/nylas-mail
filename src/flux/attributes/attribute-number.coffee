_ = require 'underscore-plus'
Attribute = require './attribute'
Matcher = require './matcher'

###
Public: The value of this attribute is always a number, or null.

Section: Database
###
class AttributeNumber extends Attribute
  toJSON: (val) -> val
  fromJSON: (val) -> unless isNaN(val) then Number(val) else null
  columnSQL: -> "#{@jsonKey} INTEGER"

  # Public: Returns a {Matcher} for objects greater than the provided value.
  greaterThan: (val) ->
    throw (new Error "this field cannot be queried against.") unless @queryable
    new Matcher(@, '>', val)

  # Public: Returns a {Matcher} for objects less than the provided value.
  lessThan: (val) ->
    throw (new Error "this field cannot be queried against.") unless @queryable
    new Matcher(@, '<', val)


module.exports = AttributeNumber
