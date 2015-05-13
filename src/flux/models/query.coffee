{Matcher, AttributeJoinedData} = require '../attributes'
_ = require 'underscore-plus'

###
Public: ModelQuery exposes an ActiveRecord-style syntax for building database queries
that return models and model counts. Model queries are returned from the factory methods
{DatabaseStore::find}, {DatabaseStore::findBy}, {DatabaseStore::findAll}, and {DatabaseStore::count}, and are the primary interface for retrieving data
from the app's local cache.

ModelQuery does not allow you to modify the local cache. To create, update or
delete items from the local cache, see {DatabaseStore::persistModel}
and {DatabaseStore::unpersistModel}.

**Simple Example:** Fetch a thread

```coffee
query = DatabaseStore.find(Thread, '123a2sc1ef4131')
query.then (thread) ->
  # thread or null
```

**Advanced Example:** Fetch 50 threads in the inbox, in descending order

```coffee
query = DatabaseStore.findAll(Thread)
query.where([Thread.attributes.tagIds.contains('inbox')])
     .order([Thread.attributes.lastMessageTimestamp.descending()])
     .limit(100).offset(50)
     .then (threads) ->
  # array of threads
```

Section: Database
###
class ModelQuery

  # Public
  # - `class` A {Model} class to query
  # - `database` (optional) An optional reference to a {DatabaseStore} the
  #   query will be executed on.
  #
  constructor: (@_klass, @_database) ->
    @_database || = require '../stores/database-store'
    @_matchers = []
    @_orders = []
    @_singular = false
    @_evaluateImmediately = false
    @_includeJoinedData = []
    @_count = false
    @

  # Public: Add one or more where clauses to the query
  #
  # - `matchers` An {Array} of {Matcher} objects that add where clauses to the underlying query.
  #
  # This method is chainable.
  #
  where: (matchers) ->
    if matchers instanceof Matcher
      @_matchers.push(matchers)
    else if matchers instanceof Array
      @_matchers = @_matchers.concat(matchers)
    else if matchers instanceof Object
      # Support a shorthand format of {id: '123', namespaceId: '123'}
      for key, value of matchers
        attr = @_klass.attributes[key]
        if !attr
          msg = "Cannot create where clause `#{key}:#{value}`. #{key} is not an attribute of #{@_klass.name}"
          throw new Error msg
        @_matchers.push(attr.equal(value))
    @

  # Public: Include specific joined data attributes in result objects.
  # - `attr` A {AttributeJoinedData} that you want to be populated in
  #  the returned models. Note: This results in a LEFT OUTER JOIN.
  #  See {AttributeJoinedData} for more information.
  #
  # This method is chainable.
  #
  include: (attr) ->
    if attr instanceof AttributeJoinedData is false
      throw new Error("query.include() must be called with a joined data attribute")
    @_includeJoinedData.push(attr)
    @

  # Public: Include all of the available joined data attributes in returned models.
  #
  # This method is chainable.
  #
  includeAll: ->
    for key, attr of @_klass.attributes
      @include(attr) if attr instanceof AttributeJoinedData
    @

  # Public: Apply a sort order to the query.
  # - `orders` An {Array} of one or more {SortOrder} objects that determine the
  #   sort order of returned models.
  #
  # This method is chainable.
  #
  order: (orders) ->
    orders = [orders] unless orders instanceof Array
    @_orders = @_orders.concat(orders)
    @

  # Public: Set the `singular` flag - only one model will be returned from the
  # query, and a `LIMIT 1` clause will be used.
  #
  # This method is chainable.
  #
  one: ->
    @_singular = true
    @

  # Public: Limit the number of query results.
  #
  # - `limit` {Number} The number of models that should be returned.
  #
  # This method is chainable.
  #
  limit: (limit) ->
    throw new Error("Cannot use limit > 2 with one()") if @_singular and limit > 1
    @_range ?= {}
    @_range.limit = limit
    @

  # Public:
  #
  # - `offset` {Number} The start offset of the query.
  #
  # This method is chainable.
  #
  offset: (offset) ->
    @_range ?= {}
    @_range.offset = offset
    @

  # Public: Set the `count` flag - instead of returning inflated models,
  # the query will return the result `COUNT`.
  #
  # This method is chainable.
  #
  count: ->
    @_count = true
    @

  ##
  # Public: Set the `evaluateImmediately` flag - instead of waiting for animations and other important user
  # interactions to complete, the query result will be processed immediately. Use with care: forcing
  # immediate evaluation can cause glitches in animations.
  #
  # This method is chainable.
  #
  evaluateImmediately: ->
    @_evaluateImmediately = true
    @

  ###
  Query Execution
  ###

  # Public: Starts query execution and returns a Promise.
  #
  # Returns a {Promise} that resolves with the Models returned by the
  # query, or rejects with an error from the Database layer.
  #
  then: (next) ->
    @_database.run(@).then(next)

  formatResult: (result) ->
    return null unless result

    if @_count
      return result[0][0] / 1
    else
      objects = []
      for i in [0..result.length-1] by 1
        row = result[i]
        json = JSON.parse(row[0])
        object = (new @_klass).fromJSON(json)
        for attr, j in @_includeJoinedData
          value = row[j+1]
          value = null if value is AttributeJoinedData.NullPlaceholder
          object[attr.modelKey] = value
        objects.push(object)
      return objects[0] if @_singular
      return objects

  # Query SQL Building

  # Returns a {String} with the SQL generated for the query.
  #
  sql: ->
    if @_count
      result = "COUNT(*) as count"
    else
      result = "`#{@_klass.name}`.`data`"
      @_includeJoinedData.forEach (attr) =>
        result += ", #{attr.selectSQL(@_klass)} "

    order = if @_count then "" else @_orderClause()
    if @_singular
      limit = "LIMIT 1"
    else if @_range?.limit
      limit = "LIMIT #{@_range.limit}"
    else
      limit = ""
    if @_range?.offset
      limit += " OFFSET #{@_range.offset}"
    "SELECT #{result} FROM `#{@_klass.name}` #{@_whereClause()} #{order} #{limit}"

  executeOptions: ->
    evaluateImmediately: @_evaluateImmediately

  _whereClause: ->
    joins = []
    @_matchers.forEach (c) =>
      join = c.joinSQL(@_klass)
      joins.push(join) if join

    @_includeJoinedData.forEach (attr) =>
      join = attr.includeSQL(@_klass)
      joins.push(join) if join

    wheres = []
    @_matchers.forEach (c) =>
      where = c.whereSQL(@_klass)
      wheres.push(where) if where

    sql = ""
    sql += joins.join(' ')
    sql += " WHERE " + wheres.join(' AND ') if wheres.length
    sql

  _orderClause: ->
    if @_orders.length == 0
      natural = @_klass.naturalSortOrder()
      @_orders.push(natural) if natural

    return "" unless @_orders.length

    sql = " ORDER BY "
    @_orders.forEach (sort) =>
      sql += sort.orderBySQL(@_klass)
    sql


module.exports = ModelQuery
