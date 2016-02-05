_ = require 'underscore'
DatabaseStore = require '../stores/database-store'
QueryRange = require './query-range'
MutableQueryResultSet = require './mutable-query-result-set'

class QuerySubscription
  constructor: (@_query, @_options = {}) ->
    @_set = null
    @_callbacks = []
    @_lastResult = null
    @_updateInFlight = false
    @_queuedChangeRecords = []
    @_queryVersion = 1

    if @_query
      if @_query._count
        throw new Error("QuerySubscriptionPool::add - You cannot listen to count queries.")

      @_query.finalize()

      if @_options.initialModels
        @_set = new MutableQueryResultSet()
        @_set.addModelsInRange(@_options.initialModels, new QueryRange({
          limit: @_options.initialModels.length,
          offset: 0
        }))
        @_createResultAndTrigger()
      else
        @update()

  query: =>
    @_query

  addCallback: (callback) =>
    unless callback instanceof Function
      throw new Error("QuerySubscription:addCallback - expects a function, received #{callback}")
    @_callbacks.push(callback)

    if @_lastResult
      process.nextTick =>
        return unless @_lastResult
        callback(@_lastResult)

  hasCallback: (callback) =>
    @_callbacks.indexOf(callback) isnt -1

  removeCallback: (callback) =>
    unless callback instanceof Function
      throw new Error("QuerySubscription:removeCallback - expects a function, received #{callback}")
    @_callbacks = _.without(@_callbacks, callback)

  callbackCount: =>
    @_callbacks.length

  applyChangeRecord: (record) =>
    return unless @_query and record.objectClass is @_query.objectClass()
    return unless record.objects.length > 0

    @_queuedChangeRecords.push(record)
    @_processChangeRecords() unless @_updateInFlight

  # Scan through change records and apply them to the last result set.
  # - Returns true if changes did / will result in new result set being created.
  # - Returns false if no changes were made.
  #
  _processChangeRecords: =>
    if @_queuedChangeRecords.length is 0
      return false
    if not @_set
      @update()
      return true

    knownImpacts = 0
    unknownImpacts = 0
    mustRefetchAllIds = false

    @_queuedChangeRecords.forEach (record) =>
      if record.type is 'unpersist'
        for item in record.objects
          offset = @_set.offsetOfId(item.clientId)
          if offset isnt -1
            @_set.removeModelAtOffset(item, offset)
            unknownImpacts += 1

      else if record.type is 'persist'
        for item in record.objects
          offset = @_set.offsetOfId(item.clientId)
          itemIsInSet = offset isnt -1
          itemShouldBeInSet = item.matches(@_query.matchers())

          if itemIsInSet and not itemShouldBeInSet
            @_set.removeModelAtOffset(item, offset)
            unknownImpacts += 1

          else if itemShouldBeInSet and not itemIsInSet
            @_set.replaceModel(item)
            mustRefetchAllIds = true
            unknownImpacts += 1

          else if itemIsInSet
            oldItem = @_set.modelWithId(item.clientId)
            @_set.replaceModel(item)

            if @_itemSortOrderHasChanged(oldItem, item)
              mustRefetchAllIds = true
              unknownImpacts += 1
            else
              knownImpacts += 1

        # If we're not at the top of the result set, we can't be sure whether an
        # item previously matched the set and doesn't anymore, impacting the items
        # in the query range. We need to refetch IDs to be sure our set is correct.
        if @_query.range().offset > 0 and (unknownImpacts + knownImpacts) < record.objects.length
          mustRefetchAllIds = true
          unknownImpacts += 1

    @_queuedChangeRecords = []

    if unknownImpacts > 0
      @_set = null if mustRefetchAllIds
      @update()
      return true
    else if knownImpacts > 0
      @_createResultAndTrigger()
      return true
    else
      return false

  _itemSortOrderHasChanged: (old, updated) ->
    for descriptor in @_query.orderSortDescriptors()
      oldSortValue = old[descriptor.attr.modelKey]
      updatedSortValue = updated[descriptor.attr.modelKey]

      # http://stackoverflow.com/questions/4587060/determining-date-equality-in-javascript
      if not (oldSortValue >= updatedSortValue && oldSortValue <= updatedSortValue)
        return true

    return false

  update: =>
    desiredRange = @_query.range()
    currentRange = @_set?.range()
    @_updateInFlight = true

    version = @_queryVersion

    if currentRange and not currentRange.isInfinite() and not desiredRange.isInfinite()
      ranges = QueryRange.rangesBySubtracting(desiredRange, currentRange)
      entireModels = true
    else
      ranges = [desiredRange]
      entireModels = not @_set or @_set.modelCacheCount() is 0

    Promise.each ranges, (range) =>
      return unless @_queryVersion is version
      @_fetchRange(range, {entireModels, version})

    .then =>
      return unless @_queryVersion is version
      ids = @_set.ids().filter (id) => not @_set.modelWithId(id)
      return if ids.length is 0
      return DatabaseStore.findAll(@_query._klass, {id: ids}).then (models) =>
        return unless @_queryVersion is version
        @_set.replaceModel(m) for m in models

    .then =>
      return unless @_queryVersion is version
      @_updateInFlight = false

      # Trigger if A) no changes came in during the update, or B) applying
      # those changes has no effect on the result set, and this one is
      # still good.
      if @_queuedChangeRecords.length is 0 or not @_processChangeRecords()
        @_createResultAndTrigger()

  cancelPendingUpdate: =>
    @_queryVersion += 1
    @_updateInFlight = false

  _fetchRange: (range, {entireModels, version} = {}) ->
    rangeQuery = undefined

    unless range.isInfinite()
      rangeQuery ?= @_query.clone()
      rangeQuery.offset(range.offset).limit(range.limit)

    unless entireModels
      rangeQuery ?= @_query.clone()
      rangeQuery.idsOnly()

    rangeQuery ?= @_query

    DatabaseStore.run(rangeQuery, {format: false}).then (results) =>
      return unless @_queryVersion is version

      if @_set and not @_set.range().isContiguousWith(range)
        @_set = null
      @_set ?= new MutableQueryResultSet()

      if entireModels
        @_set.addModelsInRange(results, range)
      else
        @_set.addIdsInRange(results, range)

      @_set.clipToRange(@_query.range())

  _createResultAndTrigger: =>
    allCompleteModels = @_set.isComplete()
    allUniqueIds = _.uniq(@_set.ids()).length is @_set.ids().length

    if not allUniqueIds
      throw new Error("QuerySubscription: Applied all changes and result set contains duplicate IDs.")

    if not allCompleteModels
      throw new Error("QuerySubscription: Applied all changes and result set is missing models.")

    if @_options.asResultSet
      @_set.setQuery(@_query)
      @_lastResult = @_set.immutableClone()
    else
      @_lastResult = @_query.formatResult(@_set.models())

    @_callbacks.forEach (callback) =>
      callback(@_lastResult)


module.exports = QuerySubscription
