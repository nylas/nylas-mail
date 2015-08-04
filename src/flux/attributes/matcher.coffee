_ = require 'underscore'
{tableNameForJoin} = require '../models/utils'

###
Public: The Matcher class encapsulates a particular comparison clause on an {Attribute}.
Matchers can evaluate whether or not an object matches them, and also compose
SQL clauses for the DatabaseStore. Each matcher has a reference to a model
attribute, a comparator and a value.

```coffee

# Retrieving Matchers

isUnread = Thread.attributes.unread.equal(true)

hasLabel = Thread.attributes.lables.contains('label-id-123')

# Using Matchers in Database Queries

DatabaseStore.findAll(Thread).where(isUnread)...

# Using Matchers to test Models

threadA = new Thread(unread: true)
threadB = new Thread(unread: false)

isUnread.evaluate(threadA)
# => true
isUnread.evaluate(threadB)
# => false

```

Section: Database
###
class Matcher
  constructor: (@attr, @comparator, @val) ->
    @muid = Matcher.muid
    Matcher.muid = (Matcher.muid + 1) % 50
    @

  attribute: ->
    @attr

  value: ->
    @val

  evaluate: (model) ->
    value = model[@attr.modelKey]
    value = value() if value instanceof Function

    switch @comparator
      when '=' then return value == @val
      when '<' then return value < @val
      when '>' then return value > @val
      when 'in' then return value in @val
      when 'contains'
        # You can provide an ID or an object, and an array of IDs or an array of objects
        # Assumes that `value` is an array of items
        !!_.find value, (x) =>
          @val == x?.id || @val == x || @val?.id == x || @val?.id == x?.id
      when 'startsWith' then return value.startsWith(@val)
      when 'like' then value.search(new RegExp(".*#{@val}.*", "gi")) >= 0
      else
        throw new Error("Matcher.evaulate() not sure how to evaluate @{@attr.modelKey} with comparator #{@comparator}")

  joinSQL: (klass) ->
    switch @comparator
      when 'contains'
        joinTable = tableNameForJoin(klass, @attr.itemClass)
        return "INNER JOIN `#{joinTable}` AS `M#{@muid}` ON `M#{@muid}`.`id` = `#{klass.name}`.`id`"
      else
        return false

  whereSQL: (klass) ->
    if @comparator is "like"
      val = "%#{@val}%"
    else
      val = @val

    if _.isString(val)
      escaped = "'#{val.replace(/'/g, "''")}'"
    else if val is true
      escaped = 1
    else if val is false
      escaped = 0
    else if val instanceof Array
      escapedVals = []
      escapedVals.push("'#{v.replace(/'/g, '\\\'')}'") for v in val
      escaped = "(#{escapedVals.join(',')})"
    else
      escaped = val

    switch @comparator
      when 'startsWith'
        return " RAISE `TODO`; "
      when 'contains'
        return "`M#{@muid}`.`value` = #{escaped}"
      else
        return "`#{klass.name}`.`#{@attr.jsonKey}` #{@comparator} #{escaped}"


Matcher.muid = 0

module.exports = Matcher
