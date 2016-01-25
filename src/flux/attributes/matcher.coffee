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
    modelValue = model[@attr.modelKey]
    modelValue = modelValue() if modelValue instanceof Function
    matcherValue = @val

    # Given an array of strings or models, and a string or model search value,
    # will find if a match exists.
    modelArrayContainsValue = (array, searchItem) ->
      asId = (v) -> if v and v.id then v.id else v
      search = asId(searchItem)
      for item in array
        return true if asId(item) == search
      return false

    switch @comparator
      when '=' then return modelValue == matcherValue
      when '<' then return modelValue < matcherValue
      when '>' then return modelValue > matcherValue
      when 'in' then return modelValue in matcherValue
      when 'contains'
        !!modelArrayContainsValue(modelValue, matcherValue)

      when 'containsAny'
        _.any matcherValue, (submatcherValue) ->
          !!modelArrayContainsValue(modelValue, submatcherValue)

      when 'startsWith' then return modelValue.startsWith(matcherValue)
      when 'like' then modelValue.search(new RegExp(".*#{matcherValue}.*", "gi")) >= 0
      else
        throw new Error("Matcher.evaulate() not sure how to evaluate @{@attr.modelKey} with comparator #{@comparator}")

  joinSQL: (klass) ->
    switch @comparator
      when 'contains', 'containsAny'
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
      for v in val
        throw new Error("#{@attr.jsonKey} value #{v} must be a string.") unless _.isString(v)
        escapedVals.push("'#{v.replace(/'/g, '\\\'')}'")
      escaped = "(#{escapedVals.join(',')})"
    else
      escaped = val

    switch @comparator
      when 'startsWith'
        return " RAISE `TODO`; "
      when 'contains'
        return "`M#{@muid}`.`value` = #{escaped}"
      when 'containsAny'
        return "`M#{@muid}`.`value` IN #{escaped}"
      else
        return "`#{klass.name}`.`#{@attr.jsonKey}` #{@comparator} #{escaped}"


Matcher.muid = 0

module.exports = Matcher
