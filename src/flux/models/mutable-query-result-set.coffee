_ = require 'underscore'
QueryRange = require './query-range'
QueryResultSet = require './query-result-set'

# TODO: Make mutator methods QueryResultSet.join(), QueryResultSet.clip...
class MutableQueryResultSet extends QueryResultSet

  immutableClone: ->
    set = new QueryResultSet({
      _ids: [].concat(@_ids)
      _modelsHash: _.extend({}, @_modelsHash)
      _query: @_query
      _offset: @_offset
    })
    Object.freeze(set)
    Object.freeze(set._ids)
    Object.freeze(set._modelsHash)
    set

  clipToRange: (range) ->
    return if range.isInfinite()
    if range.offset > @_offset
      @_ids = @_ids.slice(range.offset - @_offset)
      @_offset = range.offset

    rangeEnd = range.offset + range.limit
    selfEnd = @_offset + @_ids.length
    if (rangeEnd < selfEnd)
      @_ids.length = Math.max(0, rangeEnd - @_offset)

    models = @models()
    @_modelsHash = {}
    @_idToIndexHash = null
    @replaceModel(m) for m in models

  addModelsInRange: (rangeModels, range) ->
    @addIdsInRange(_.pluck(rangeModels, 'id'), range)
    @replaceModel(m) for m in rangeModels

  addIdsInRange: (rangeIds, range) ->
    if @_offset is null or range.isInfinite()
      @_ids = rangeIds
      @_idToIndexHash = null
      @_offset = range.offset
    else
      currentEnd = @_offset + @_ids.length
      rangeIdsEnd = range.offset + rangeIds.length

      if rangeIdsEnd < @_offset
        throw new Error("addIdsInRange: You can only add adjacent values (#{rangeIdsEnd} < #{@_offset})")
      if range.offset > currentEnd
        throw new Error("addIdsInRange: You can only add adjacent values (#{range.offset} > #{currentEnd})")

      existingBefore = []
      if range.offset > @_offset
        existingBefore = @_ids.slice(0, range.offset - @_offset)

      existingAfter = []
      if rangeIds.length is range.limit and currentEnd > rangeIdsEnd
        existingAfter = @_ids.slice(rangeIdsEnd - @_offset)

      @_ids = [].concat(existingBefore, rangeIds, existingAfter)
      @_idToIndexHash = null
      @_offset = Math.min(@_offset, range.offset)

  replaceModel: (item) ->
    return unless item
    @_modelsHash[item.clientId] = item
    @_modelsHash[item.id] = item
    @_idToIndexHash = null

  removeModelAtOffset: (item, offset) ->
    idx = offset - @_offset
    delete @_modelsHash[item.clientId]
    delete @_modelsHash[item.id]
    @_ids.splice(idx, 1)
    @_idToIndexHash = null

  setQuery: (query) ->
    @_query = query.clone()
    @_query.finalize()

module.exports = MutableQueryResultSet
