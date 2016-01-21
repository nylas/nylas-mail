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
    set

  constructor: (other = {}) ->
    @_modelsHash = other._modelsHash ? {}
    @_offset = other._offset ? null
    @_ids = other._ids ? []

  clone: ->
    new @constructor({
      _ids: [].concat(@_ids)
      _modelsHash: _.extend({}, @_modelsHash)
      _offset: @_offset
    })

  isComplete: ->
    _.every @_ids, (id) => @_modelsHash[id]

  range: ->
    new QueryRange(offset: @_offset, limit: @_ids.length)

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

  offsetOfId: (id) ->
    idx = @_ids.indexOf(id)

    # If we can't find the item, try to match against client ids as well. Some
    # items in the models() array may not be loaded, but we can try our best.
    if idx is -1
      idx = _.findIndex @models(), (m) -> m and (m.id is id or m.clientId is id)

    return -1 if idx is -1
    return @_offset + idx

module.exports = QueryResultSet
