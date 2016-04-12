_ = require 'underscore'
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
    throw (new Error "AttributeNumber::greaterThan (#{@modelKey}) - you must provide a value") unless val?
    throw (new Error "AttributeNumber::greaterThan (#{@modelKey}) - this field cannot be queried against") unless @queryable
    new Matcher(@, '>', val)

  # Public: Returns a {Matcher} for objects less than the provided value.
  lessThan: (val) ->
    throw (new Error "AttributeNumber::lessThan (#{@modelKey}) - you must provide a value") unless val?
    throw (new Error "AttributeNumber::lessThan (#{@modelKey}) - this field cannot be queried against") unless @queryable
    new Matcher(@, '<', val)

  # Public: Returns a {Matcher} for objects greater than the provided value.
  greaterThanOrEqualTo: (val) ->
    throw (new Error "AttributeNumber::greaterThanOrEqualTo (#{@modelKey}) - you must provide a value") unless val?
    throw (new Error "AttributeNumber::greaterThanOrEqualTo (#{@modelKey}) - this field cannot be queried against") unless @queryable
    new Matcher(@, '>=', val)

  # Public: Returns a {Matcher} for objects less than the provided value.
  lessThanOrEqualTo: (val) ->
    throw (new Error "AttributeNumber::lessThanOrEqualTo (#{@modelKey}) - you must provide a value") unless val?
    throw (new Error "AttributeNumber::lessThanOrEqualTo (#{@modelKey}) - this field cannot be queried against") unless @queryable
    new Matcher(@, '<=', val)

  gt: AttributeNumber::greaterThan
  lt: AttributeNumber::lessThan
  gte: AttributeNumber::greaterThanOrEqualTo
  lte: AttributeNumber::lessThanOrEqualTo

module.exports = AttributeNumber
