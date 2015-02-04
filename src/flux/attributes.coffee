_ = require 'underscore-plus'
{tableNameForJoin} = require './models/utils'

# The Matcher class encapsulates a particular comparison clause on an attribute.
# Matchers can evaluate whether or not an object matches them, and in the future
# they will also compose WHERE clauses. Each matcher has a reference to a model
# attribute, a comparator and a value.
class Matcher
  constructor: (@attr, @comparator, @val) ->
    @muid = Matcher.muid
    Matcher.muid = (Matcher.muid + 1) % 50
    @

  evaluate: (model) ->
    value = model[@attr.modelKey]
    value = value() if value instanceof Function

    switch @comparator
      when '=' then return value == @val
      when '<' then return value < @val
      when '>' then return value > @val
      when 'contains'
        # You can provide an ID or an object, and an array of IDs or an array of objects
        # Assumes that `value` is an array of items
        !!_.find value, (x) =>
          @val == x?.id || @val == x || @val?.id == x || @val?.id == x?.id
      when 'startsWith' then return value.startsWith(@val)

  joinSQL: (klass) ->
    switch @comparator
      when 'contains'
        joinTable = tableNameForJoin(klass, @attr.itemClass)
        return "INNER JOIN `#{joinTable}` AS `M#{@muid}` ON `M#{@muid}`.`id` = `#{klass.name}`.`id`"
      else
        return false

  whereSQL: (klass) ->
    if _.isString(@val)
      escaped = "'#{@val.replace(/'/g, '\\\'')}'"
    else if @val is true
      escaped = 1
    else if @val is false
      escaped = 0
    else
      escaped = @val

    switch @comparator
      when 'startsWith'
        return " RAISE `TODO`; "
      when 'contains'
        return "`M#{@muid}`.`value` = #{escaped}"
      else
        return "`#{@attr.jsonKey}` #{@comparator} #{escaped}"


class SortOrder
  constructor: (@attr, @direction = 'DESC') ->
  orderBySQL: (klass) ->
    "`#{klass.name}`.`#{@attr.jsonKey}` #{@direction}"

# The Attribute class represents a single model attribute, like 'namespace_id'
# Subclasses of Attribute like AttributeDateTime know how to covert between
# the JSON representation of that type and the javascript representation.
# The Attribute class also exposes convenience methods for generating Matchers.
class Attribute
  constructor: ({modelKey, queryable, jsonKey}) ->
    @modelKey = modelKey
    @jsonKey = jsonKey || modelKey
    @queryable = queryable
    @

  equal: (val) ->
    throw (new Error "this field cannot be queried against.") unless @queryable
    new Matcher(@, '=', val)
  greaterThan: (val) ->
    throw (new Error "this field cannot be queried against.") unless @queryable
    new Matcher(@, '>', val)
  lessThan: (val) ->
    throw (new Error "this field cannot be queried against.") unless @queryable
    new Matcher(@, '<', val)
  contains: (val) ->
    throw (new Error "this field cannot be queried against.") unless @queryable
    new Matcher(@, 'contains', val)
  startsWith: (val) ->
    throw new Error "startsWith cannot be applied to #{@.constructor.name}"
  descending: ->
    new SortOrder(@, 'DESC')
  ascending: ->
    new SortOrder(@, 'ASC')
  toJSON: (val) -> val
  fromJSON: (val) -> val || null

class AttributeNumber extends Attribute
  toJSON: (val) -> val
  fromJSON: (val) -> val || null
  columnSQL: -> "#{@jsonKey} INTEGER"

class AttributeBoolean extends Attribute
  toJSON: (val) -> val
  fromJSON: (val) -> (val is 'true' or val is true) || false
  greaterThan: (val) -> throw new Error "greaterThan cannot be applied to AttributeBoolean"
  lessThan: (val) -> throw new Error "greaterThan cannot be applied to AttributeBoolean"
  columnSQL: -> "#{@jsonKey} INTEGER"

class AttributeString extends Attribute
  toJSON: (val) -> val
  fromJSON: (val) -> val || ""
  greaterThan: (val) -> throw new Error "greaterThan cannot be applied to AttributeString"
  lessThan: (val) -> throw new Error "greaterThan cannot be applied to AttributeString"
  startsWith: (val) -> new Matcher(@, 'startsWith', val)
  columnSQL: -> "#{@jsonKey} TEXT"

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

class AttributeCollection extends Attribute
  constructor: ({modelKey, jsonKey, itemClass}) ->
    super
    @itemClass = itemClass
    @

  toJSON: (vals) ->
    return [] unless vals
    json = []
    for val in vals
      unless val instanceof @itemClass
        msg = "AttributeCollection.toJSON: Value `#{val}` in #{@modelKey} is not an #{@itemClass.name}"
        throw new Error msg
      if val.toJSON?
        json.push(val.toJSON())
      else
        json.push(val)
    json

  fromJSON: (json) ->
    return [] unless json && json instanceof Array
    objs = []
    for objJSON in json
      obj = new @itemClass(objJSON)
      obj.fromJSON(objJSON) if obj.fromJSON?
      objs.push(obj)
    objs

Matcher.muid = 0

module.exports = {
  Number: -> new AttributeNumber(arguments...)
  String: -> new AttributeString(arguments...)
  DateTime: -> new AttributeDateTime(arguments...)
  Collection: -> new AttributeCollection(arguments...)
  Boolean: -> new AttributeBoolean(arguments...)
  Object: -> new Attribute(arguments...)
  
  AttributeNumber: AttributeNumber
  AttributeString: AttributeString
  AttributeDateTime: AttributeDateTime
  AttributeCollection: AttributeCollection
  AttributeBoolean: AttributeBoolean

  SortOrder: SortOrder
  Matcher: Matcher
}
