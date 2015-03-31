{Matcher, NullPlaceholder, AttributeJoinedData} = require '../attributes'
_ = require 'underscore-plus'

class ModelQuery

  constructor: (@_klass, @_database) ->
    @_database || = require '../stores/database-store'
    @_matchers = []
    @_orders = []
    @_singular = false
    @_evaluateImmediately = false
    @_includeJoinedData = []
    @_count = false
    @

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
  
  include: (attr) ->
    if attr instanceof AttributeJoinedData is false
      throw new Error("query.include() must be called with a joined data attribute")
    @_includeJoinedData.push(attr)
    @

  includeAll: ->
    for key, attr of @_klass.attributes
      @include(attr) if attr instanceof AttributeJoinedData
    @

  order: (orders) ->
    orders = [orders] unless orders instanceof Array
    @_orders = @_orders.concat(orders)
    @

  one: ->
    @_singular = true
    @

  limit: (limit) ->
    throw new Error("Cannot use limit > 2 with one()") if @_singular and limit > 1
    @_range ?= {}
    @_range.limit = limit
    @

  offset: (offset) ->
    @_range ?= {}
    @_range.offset = offset
    @

  count: ->
    @_count = true
    @
  
  evaluateImmediately: ->
    @_evaluateImmediately = true

  # Query Execution

  then: (next) ->
    @_database.run(@).then(next)

  formatResult: (result) ->
    return null unless result

    if @_count
      return result[0][0]
    else
      objects = []
      for i in [0..result.length-1] by 1
        row = result[i]
        json = JSON.parse(row[0])
        object = (new @_klass).fromJSON(json)
        for attr, j in @_includeJoinedData
          value = row[j+1]
          value = null if value is NullPlaceholder
          object[attr.modelKey] = value
        objects.push(object)
      return objects[0] if @_singular
      return objects

  # Query SQL Building

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
