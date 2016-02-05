Attribute = require './attribute'
Matcher = require './matcher'

###
Public: The value of this attribute is always a string or `null`.

String attributes can be queries using `equal`, `not`, and `startsWith`. Matching on
`greaterThan` and `lessThan` is not supported.

Section: Database
###
class AttributeString extends Attribute
  toJSON: (val) -> val
  fromJSON: (val) ->
    return null if val is null or val is undefined or val is false
    return val + ""


  # Public: Returns a {Matcher} for objects starting with the provided value.
  startsWith: (val) -> new Matcher(@, 'startsWith', val)

  columnSQL: -> "#{@jsonKey} TEXT"

  like: (val) ->
    throw (new Error "AttributeString::like (#{@modelKey}) - you must provide a value") unless val?
    throw (new Error "AttributeString::like (#{@modelKey}) - this field cannot be queried against") unless @queryable
    new Matcher(@, 'like', val)

module.exports = AttributeString
