_ = require 'underscore'
Attribute = require './attribute'
Matcher = require './matcher'

###
Public: The value of this attribute is always a Javascript `Date`, or `null`.

Section: Database
###
class AttributeDateTime extends Attribute
  toJSON: (val) ->
    return null unless val
    unless val instanceof Date
      throw new Error "Attempting to toJSON AttributeDateTime which is not a date: #{@modelKey} = #{val}"
    val.getTime() / 1000.0

  fromJSON: (val) ->
    return null unless val
    new Date(val*1000)

  columnSQL: -> "#{@jsonKey} INTEGER"

  # Public: Returns a {Matcher} for objects greater than the provided value.
  greaterThan: (val) ->
    throw (new Error "AttributeDateTime::greaterThan (#{@modelKey}) - you must provide a value") unless val?
    throw (new Error "AttributeDateTime::greaterThan (#{@modelKey}) - this field cannot be queried against") unless @queryable
    new Matcher(@, '>', val)

  # Public: Returns a {Matcher} for objects less than the provided value.
  lessThan: (val) ->
    throw (new Error "AttributeDateTime::lessThan (#{@modelKey}) - you must provide a value") unless val?
    throw (new Error "AttributeDateTime::lessThan (#{@modelKey}) - this field cannot be queried against") unless @queryable
    new Matcher(@, '<', val)


module.exports = AttributeDateTime
