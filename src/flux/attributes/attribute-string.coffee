Attribute = require './attribute'
Matcher = require './matcher'

###
Public: The value of this attribute is always a string or `null`.

String attributes can be queries using `equal`, `not`, and `startsWith`. Matching on
`greaterThan` and `lessThan` is not supported.
###
class AttributeString extends Attribute
  toJSON: (val) -> val
  fromJSON: (val) -> val || ""

  # Public: Returns a {Matcher} for objects starting with the provided value.
  startsWith: (val) -> new Matcher(@, 'startsWith', val)

  columnSQL: -> "#{@jsonKey} TEXT"

  like: (val) ->
    throw (new Error "this field cannot be queried against.") unless @queryable
    new Matcher(@, 'like', val)

module.exports = AttributeString