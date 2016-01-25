_ = require 'underscore'
DatabaseStore = require '../stores/database-store'
QueryRange = require './query-range'
MutableQueryResultSet = require './mutable-query-result-set'

verbose = false

class QuerySubscription
  constructor: (@_query, @_options = {}) ->
    @_set = null
    @_version = 0
    @_callbacks = []
    @_lastResult = null

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

    return @update() if not @_set

    impactCount = 0
    mustRefetchAllIds = false

    if record.type is 'unpersist'
      for item in record.objects
        offset = @_set.offsetOfId(item.clientId)
        if offset isnt -1
          @_set.removeModelAtOffset(item, offset)
          impactCount += 1

    else if record.type is 'persist'
      for item in record.objects
        offset = @_set.offsetOfId(item.clientId)
        itemIsInSet = offset isnt -1
        itemShouldBeInSet = item.matches(@_query.matchers())

        if itemIsInSet and not itemShouldBeInSet
          @_set.removeModelAtOffset(item, offset)
          impactCount += 1

        else if itemShouldBeInSet and not itemIsInSet
          @_set.replaceModel(item)
          mustRefetchAllIds = true
          impactCount += 1

        else if itemIsInSet
          oldItem = @_set.modelWithId(item.clientId)
          @_set.replaceModel(item)
          impactCount += 1
          mustRefetchAllIds = true if @_itemSortOrderHasChanged(oldItem, item)

    if impactCount > 0
      if mustRefetchAllIds
        @log("Clearing result set - mustRefetchAllIds")
        @_set = null
      @update()

  _itemSortOrderHasChanged: (old, updated) ->
    for descriptor in @_query.orderSortDescriptors()
      oldSortValue = old[descriptor.attr.modelKey]
      updatedSortValue = updated[descriptor.attr.modelKey]

      # http://stackoverflow.com/questions/4587060/determining-date-equality-in-javascript
      if not (oldSortValue >= updatedSortValue && oldSortValue <= updatedSortValue)
        return true

    return false

  log: (msg) =>
    return unless verbose
    console.log(msg) if @_query._klass.name is 'Thread'

  update: =>
    version = @_version += 1

    desiredRange = @_query.range()
    currentRange = @_set?.range()

    if currentRange and not currentRange.isInfinite() and not desiredRange.isInfinite()
      ranges = QueryRange.rangesBySubtracting(desiredRange, currentRange)
      entireModels = true
    else
      ranges = [desiredRange]
      entireModels = not @_set or @_set.modelCacheCount() is 0

    Promise.each ranges, (range) =>
      return @log("Update (#{version}) - Cancelled @ Step 0") unless version is @_version
      @log("Update (#{version}) - Fetching range #{range}")
      @_fetchRange(range, {entireModels, version})
    .then =>
      return @log("Update (#{version}) - Cancelled @ Step 1") unless version is @_version
      ids = @_set.ids().filter (id) => not @_set.modelWithId(id)
      return @log("Update (#{version}) - No missing Ids") if ids.length is 0
      @log("Update (#{version}) - Fetching missing Ids: #{ids}")
      return DatabaseStore.findAll(@_query._klass, {id: ids}).then (models) =>
        @log("Update (#{version}) - Fetched missing Ids")
        @_set.replaceModel(m) for m in models
    .then =>
      return @log("Update (#{version}) - Cancelled @ Step 2") unless version is @_version
      @log("Update (#{version}) - Triggering...")
      @_createResultAndTrigger()

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
      if version and version isnt @_version
        return @log("Update (#{version}) - fetchRange Cancelled")

      unless @_set?.range().isContiguousWith(range)
        @log("Clearing result set - #{range} isnt contiguous with #{@_set?.range()}")
        @_set = null
      @_set ?= new MutableQueryResultSet()

      if entireModels
        @_set.addModelsInRange(results, range)
      else
        @_set.addIdsInRange(results, range)

      @_set.clipToRange(@_query.range())

  _createResultAndTrigger: =>
    unless @_set.isComplete()
      console.warn("QuerySubscription: tried to publish a result set missing models.")
      return

    ids = @_set.ids()
    unless _.uniq(ids).length is ids.length
      throw new Error("QuerySubscription: result set contains duplicate ids.")

    if @_options.asResultSet
      @_lastResult = @_set.immutableClone()
    else
      @_lastResult = @_query.formatResult(@_set.models())

    @_callbacks.forEach (callback) =>
      callback(@_lastResult)


module.exports = QuerySubscription
