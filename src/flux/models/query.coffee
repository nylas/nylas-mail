{Matcher, AttributeJoinedData} = require '../attributes'
QueryRange = require './query-range'
Utils = require './utils'
_ = require 'underscore'

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
query.where([Thread.attributes.categories.contains('label-id')])
     .order([Thread.attributes.lastMessageReceivedTimestamp.descending()])
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
    @_distinct = false
    @_range = QueryRange.infinite()
    @_returnOne = false
    @_returnIds = false
    @_includeJoinedData = []
    @_count = false
    @

  clone: ->
    q = new ModelQuery(@_klass, @_database).where(@_matchers).order(@_orders)
    q._orders = [].concat(@_orders)
    q._includeJoinedData = [].concat(@_includeJoinedData)
    q._range = @_range.clone()
    q._distinct = @_distinct
    q._returnOne = @_returnOne
    q._returnIds = @_returnIds
    q._count = @_count
    q

  distinct: ->
    @_distinct = true
    @

  # Public: Add one or more where clauses to the query
  #
  # - `matchers` An {Array} of {Matcher} objects that add where clauses to the underlying query.
  #
  # This method is chainable.
  #
  where: (matchers) ->
    @_assertNotFinalized()

    if matchers instanceof Matcher
      @_matchers.push(matchers)
    else if matchers instanceof Array
      for m in matchers
        throw new Error("You must provide instances of `Matcher`") unless m instanceof Matcher
      @_matchers = @_matchers.concat(matchers)
    else if matchers instanceof Object
      # Support a shorthand format of {id: '123', accountId: '123'}
      for key, value of matchers
        attr = @_klass.attributes[key]
        if !attr
          msg = "Cannot create where clause `#{key}:#{value}`. #{key} is not an attribute of #{@_klass.name}"
          throw new Error msg

        if value instanceof Array
          @_matchers.push(attr.in(value))
        else
          @_matchers.push(attr.equal(value))
    @

  whereAny: (matchers) ->
    @_assertNotFinalized()
    @_matchers.push(new Matcher.Or(matchers))
    @

  search: (query) ->
    @_assertNotFinalized()
    @_matchers.push(new Matcher.Search(query))
    @

  # Public: Include specific joined data attributes in result objects.
  # - `attr` A {AttributeJoinedData} that you want to be populated in
  #  the returned models. Note: This results in a LEFT OUTER JOIN.
  #  See {AttributeJoinedData} for more information.
  #
  # This method is chainable.
  #
  include: (attr) ->
    @_assertNotFinalized()
    if attr instanceof AttributeJoinedData is false
      throw new Error("query.include() must be called with a joined data attribute")
    @_includeJoinedData.push(attr)
    @

  # Public: Include all of the available joined data attributes in returned models.
  #
  # This method is chainable.
  #
  includeAll: ->
    @_assertNotFinalized()
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
    @_assertNotFinalized()
    orders = [orders] unless orders instanceof Array
    @_orders = @_orders.concat(orders)
    @

  # Public: Set the `singular` flag - only one model will be returned from the
  # query, and a `LIMIT 1` clause will be used.
  #
  # This method is chainable.
  #
  one: ->
    @_assertNotFinalized()
    @_returnOne = true
    @

  # Public: Limit the number of query results.
  #
  # - `limit` {Number} The number of models that should be returned.
  #
  # This method is chainable.
  #
  limit: (limit) ->
    @_assertNotFinalized()
    throw new Error("Cannot use limit > 2 with one()") if @_returnOne and limit > 1
    @_range = @_range.clone()
    @_range.limit = limit
    @

  # Public:
  #
  # - `offset` {Number} The start offset of the query.
  #
  # This method is chainable.
  #
  offset: (offset) ->
    @_assertNotFinalized()
    @_range = @_range.clone()
    @_range.offset = offset
    @

  # Public:
  #
  # A convenience method for setting both limit and offset given a desired page size.
  #
  page: (start, end, pageSize = 50, pagePadding = 100) ->
    roundToPage = (n) -> Math.max(0, Math.floor(n / pageSize) * pageSize)
    @offset(roundToPage(start - pagePadding))
    @limit(roundToPage((end - start) + pagePadding * 2))
    @

  # Public: Set the `count` flag - instead of returning inflated models,
  # the query will return the result `COUNT`.
  #
  # This method is chainable.
  #
  count: ->
    @_assertNotFinalized()
    @_count = true
    @

  idsOnly: ->
    @_returnIds = true
    @

  ###
  Query Execution
  ###

  # Public: Short-hand syntax that calls run().then(fn) with the provided function.
  #
  # Returns a {Promise} that resolves with the Models returned by the
  # query, or rejects with an error from the Database layer.
  #
  then: (next) ->
    @run(@).then(next)

  # Public: Returns a {Promise} that resolves with the Models returned by the
  # query, or rejects with an error from the Database layer.
  #
  run: ->
    @_database.run(@)

  inflateResult: (result) ->
    return null unless result

    if @_count
      return result[0]['count'] / 1
    else if @_returnIds
      return result.map (row) -> row['id']
    else
      try
        objects = result.map (row) =>
          json = JSON.parse(row['data'], Utils.registeredObjectReviver)
          object = (new @_klass).fromJSON(json)
          for attr in @_includeJoinedData
            value = row[attr.jsonKey]
            value = null if value is AttributeJoinedData.NullPlaceholder
            object[attr.modelKey] = value
          object
      catch jsonError
        throw new Error("Query could not parse the database result. Query: #{@sql()}, Error: #{jsonError.toString()}")
      return objects

  formatResult: (inflated) ->
    return inflated[0] if @_returnOne
    return inflated if @_count
    return [].concat(inflated)

  # Query SQL Building

  # Returns a {String} with the SQL generated for the query.
  #
  sql: ->
    @finalize()

    if @_count
      result = "COUNT(*) as count"
    else if @_returnIds
      result = "`#{@_klass.name}`.`id`"
    else
      result = "`#{@_klass.name}`.`data`"
      @_includeJoinedData.forEach (attr) =>
        result += ", #{attr.selectSQL(@_klass)} "

    order = if @_count then "" else @_orderClause()
    if @_range.limit?
      limit = "LIMIT #{@_range.limit}"
    else
      limit = ""
    if @_range.offset?
      limit += " OFFSET #{@_range.offset}"

    distinct = if @_distinct then ' DISTINCT' else ''
    "SELECT#{distinct} #{result} FROM `#{@_klass.name}` #{@_whereClause()} #{order} #{limit}"

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
    return "" unless @_orders.length

    sql = " ORDER BY "
    @_orders.forEach (sort) =>
      sql += sort.orderBySQL(@_klass)
    sql

  # Private: Marks the object as final, preventing any changes to the where
  # clauses, orders, etc.
  finalize: ->
    return if @_finalized

    if @_orders.length is 0
      natural = @_klass.naturalSortOrder()
      @_orders.push(natural) if natural

    if @_returnOne and not @_range.limit
      @limit(1)

    @_finalized = true
    @

  # Private: Throws an exception if the query has been frozen.
  _assertNotFinalized: ->
    if @_finalized
      throw new Error("ModelQuery: You cannot modify a query after calling `then` or `listen`")

  # Introspection
  # (These are here to make specs easy)

  matchers: ->
    @_matchers

  matcherValueForModelKey: (key) ->
    matcher = _.find @_matchers, (m) -> m.attr.modelKey = key
    matcher?.val

  range: ->
    @_range

  orderSortDescriptors: ->
    @_orders

  objectClass: ->
    @_klass.name

module.exports = ModelQuery
