_ = require 'underscore'
QueryRange = require './query-range'

###
Public: Instances of QueryResultSet hold a set of models retrieved
from the database at a given offset.

Complete vs Incomplete:

QueryResultSet keeps an array of item ids and a lookup table of models.
The lookup table may be incomplete if the QuerySubscription isn't finished
preparing results. You can use `isComplete` to determine whether the set
has every model.

Offset vs Index:

To avoid confusion, "index" refers to an item's position in an
array, and "offset" refers to it's position in the query result set. For example,
an item might be at index 20 in the _ids array, but at offset 120 in the result.

Ids and clientIds:

QueryResultSet calways returns object `ids` when asked for ids, but lookups
for models by clientId work once models are loaded.

###
class QueryResultSet

  @setByApplyingModels: (set, models) ->
    if models instanceof Array
      throw new Error("setByApplyingModels: A hash of models is required.")
    set = set.clone()
    set._modelsHash = models
    set._idToIndexHash = null
    set

  constructor: (other = {}) ->
    @_modelsHash = other._modelsHash ? {}
    @_offset = other._offset ? null
    @_query = other._query ? null
    @_ids = other._ids ? []
    @_idToIndexHash = other._idToIndexHash ? null

  clone: ->
    new @constructor({
      _ids: [].concat(@_ids)
      _modelsHash: _.extend({}, @_modelsHash)
      _idToIndexHash: _.extend({}, @_idToIndexHash)
      _query: @_query
      _offset: @_offset
    })

  isComplete: ->
    _.every @_ids, (id) => @_modelsHash[id]

  range: ->
    new QueryRange(offset: @_offset, limit: @_ids.length)

  query: ->
    @_query

  count: ->
    @_ids.length

  empty: ->
    @count() is 0

  ids: ->
    @_ids

  idAtOffset: (offset) ->
    @_ids[offset - @_offset]

  models: ->
    @_ids.map (id) => @_modelsHash[id]

  modelCacheCount: ->
    Object.keys(@_modelsHash).length

  modelAtOffset: (offset) ->
    unless _.isNumber(offset)
      throw new Error("QueryResultSet.modelAtOffset() takes a numeric index. Maybe you meant modelWithId()?")
    @_modelsHash[@_ids[offset - @_offset]]

  modelWithId: (id) ->
    @_modelsHash[id]

  buildIdToIndexHash: ->
    @_idToIndexHash = {}
    for id, idx in @_ids
      @_idToIndexHash[id] = idx
      model = @_modelsHash[id]
      @_idToIndexHash[model.clientId] = idx if model

  offsetOfId: (id) ->
    if @_idToIndexHash is null
      @buildIdToIndexHash()

    if @_idToIndexHash[id]
      return @_idToIndexHash[id] + @_offset
    else
      return -1

module.exports = QueryResultSet
