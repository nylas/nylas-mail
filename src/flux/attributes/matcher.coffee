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

hasLabel = Thread.attributes.categories.contains('label-id-123')

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
      when '<=' then return modelValue <= matcherValue
      when '>=' then return modelValue >= matcherValue
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

    # https://www.sqlite.org/faq.html#q14
    # That's right. Two single quotes in a row…
    singleQuoteEscapeSequence = "''"

    if @comparator is "like"
      val = "%#{@val}%"
    else
      val = @val

    if _.isString(val)
      escaped = "'#{val.replace(/'/g, singleQuoteEscapeSequence)}'"
    else if val is true
      escaped = 1
    else if val is false
      escaped = 0
    else if val instanceof Array
      escapedVals = []
      for v in val
        throw new Error("#{@attr.jsonKey} value #{v} must be a string.") unless _.isString(v)
        escapedVals.push("'#{v.replace(/'/g, singleQuoteEscapeSequence)}'")
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

class OrCompositeMatcher extends Matcher
  constructor: (@children) ->
    @

  attribute: =>
    null

  value: =>
    null

  evaluate: (model) =>
    for matcher in @children
      return true if matcher.evaluate(model)
    return false

  joinSQL: (klass) =>
    joins = []
    for matcher in @children
      join = matcher.joinSQL(klass)
      joins.push(join) if join
    if joins.length
      return joins.join(" ")
    else
      return false

  whereSQL: (klass) =>
    wheres = []
    for matcher in @children
      wheres.push(matcher.whereSQL(klass))
    return "(" + wheres.join(" OR ") + ")"

class AndCompositeMatcher extends Matcher
  constructor: (@children) ->
    @

  attribute: =>
    null

  value: =>
    null

  evaluate: (model) =>
    _.every @children, (matcher) -> matcher.evaluate(model)

  joinSQL: (klass) =>
    joins = []
    for matcher in @children
      join = matcher.joinSQL(klass)
      joins.push(join) if join
    return joins

  whereSQL: (klass) =>
    wheres = []
    for matcher in @children
      wheres.push(matcher.whereSQL(klass))
    return "(" + wheres.join(" AND ") + ")"

class NotCompositeMatcher extends Matcher
  constructor: (@children) ->
    @

  attribute: =>
    null

  value: =>
    null

  evaluate: (model) =>
    not _.every(@children, (matcher) -> matcher.evaluate(model))

  joinSQL: (klass) =>
    joins = []
    for matcher in @children
      join = matcher.joinSQL(klass)
      joins.push(join) if join
    return joins

  whereSQL: (klass) =>
    wheres = []
    for matcher in @children
      wheres.push(matcher.whereSQL(klass))
    return "NOT (" + wheres.join(" AND ") + ")"

class SearchMatcher extends Matcher
  constructor: (@searchQuery) ->
    super(null, null, null)
    @

  attribute: =>
    null

  value: =>
    null

  # The only way to truly check if a model matches this matcher is to run the query
  # again and check if the model is in the results. This is too expensive, so we
  # will always return true so models aren't excluded from the
  # SearchQuerySubscription result set
  evaluate: (model) =>
    true

  joinSQL: (klass) =>
    searchTable = "#{klass.name}Search"
    return "INNER JOIN `#{searchTable}` AS `M#{@muid}` ON `M#{@muid}`.`content_id` = `#{klass.name}`.`id`"

  whereSQL: (klass) =>
    searchTable = "#{klass.name}Search"
    return "`#{searchTable}` MATCH '\"#{@searchQuery}\"'"

Matcher.muid = 0
Matcher.Or = OrCompositeMatcher
Matcher.And = AndCompositeMatcher
Matcher.Not = NotCompositeMatcher
Matcher.Search = SearchMatcher

module.exports = Matcher
