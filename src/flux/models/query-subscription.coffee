_ = require 'underscore'
DatabaseChangeRecord = require '../stores/database-change-record'

class QuerySubscription
  constructor: (@_query, @_options) ->
    ModelQuery = require './query'

    if not @_query or not (@_query instanceof ModelQuery)
      throw new Error("QuerySubscription: Must be constructed with a ModelQuery. Got #{@_query}")

    if @_query._count
      throw new Error("QuerySubscriptionPool::add - You cannot listen to count queries.")

    @_query.finalize()
    @_limit = @_query.range().limit ? Infinity
    @_offset = @_query.range().offset ? 0

    @_callbacks = []
    @_version = 0
    @_versionFetchInProgress = false
    @_lastResultSet = null
    @_refetchResultSet()

  query: =>
    @_query

  addCallback: (callback) =>
    unless callback instanceof Function
      throw new Error("QuerySubscription:addCallback - expects a function, received #{callback}")
    @_callbacks.push(callback)

    # If we already have data, send it to our new observer. Users always expect
    # callbacks to be fired asynchronously, so wait a tick.
    if @_lastResultSet
      _.defer => @_invokeCallback(callback)

  hasCallback: (callback) =>
    @_callbacks.indexOf(callback) isnt -1

  removeCallback: (callback) =>
    unless callback instanceof Function
      throw new Error("QuerySubscription:removeCallback - expects a function, received #{callback}")
    @_callbacks = _.without(@_callbacks, callback)

  callbackCount: =>
    @_callbacks.length

  applyChangeRecord: (record) =>
    return unless record.objectClass is @_query.objectClass()
    return unless record.objects.length > 0
    return @_invalidatePendingResultSet() unless @_lastResultSet

    @_lastResultSet = [].concat(@_lastResultSet)

    if record.type is 'unpersist'
      status = @_optimisticallyRemoveModels(record.objects)
    else if record.type is 'persist'
      status = @_optimisticallyUpdateModels(record.objects)
    else
      throw new Error("QuerySubscription: Unknown change record type: #{record.type}")

    if status.setModified
      @_invokeCallbacks()
    if status.setFetchRequired
      @_refetchResultSet()

  _refetchResultSet: =>
    @_version += 1

    return if @_versionFetchInProgress
    @_versionFetchInProgress = true
    fetchVersion = @_version

    DatabaseStore = require '../stores/database-store'
    DatabaseStore.run(@_query, {format: false}).then (result) =>
      @_versionFetchInProgress = false
      if @_version is fetchVersion
        @_lastResultSet = result
        @_invokeCallbacks()
      else
        @_refetchResultSet()

  _invalidatePendingResultSet: =>
    @_version += 1

  _resortResultSet: =>
    sortDescriptors = @_query.orderSortDescriptors()
    @_lastResultSet.sort (a, b) ->
      for descriptor in sortDescriptors
        if descriptor.direction is 'ASC'
          direction = 1
        else if descriptor.direction is 'DESC'
          direction = -1
        else
          throw new Error("QuerySubscription: Unknown sort order: #{descriptor.direction}")
        aValue = a[descriptor.attr.modelKey]
        bValue = b[descriptor.attr.modelKey]
        return -1 * direction if aValue < bValue
        return 1 * direction if aValue > bValue
      return 0

  _optimisticallyRemoveModels: (items) =>
    status =
      setModified: false
      setFetchRequired: false

    lastLength = @_lastResultSet.length

    for item in items
      idx = _.findIndex @_lastResultSet, ({id}) -> id is item.id
      if idx isnt -1
        @_lastResultSet.splice(idx, 1)
        status.setModified = true

        # Removing items is an issue if we previosly had LIMIT items. This
        # means there are likely more items to display in the place of the one
        # we're removing and we need to re-fetch
        if lastLength is @_limit
          status.setFetchRequired = true

    status

  _optimisticallyUpdateModels: (items) =>
    status =
      setModified: false
      setFetchRequired: false

    sortNecessary = false

    # Pull attributes of the query
    sortDescriptors = @_query.orderSortDescriptors()

    oldSetInfo =
      length: @_lastResultSet.length
      startItem: @_lastResultSet[0]
      endItem: @_lastResultSet[@_limit - 1]

    for item in items
      # TODO
      # This logic is duplicated across DatabaseView#invalidate and
      # ModelView#indexOf
      #
      # This duplication should go away when we refactor/replace DatabaseView
      # for using observables
      idx = _.findIndex @_lastResultSet, ({id, clientId}) ->
        id is item.id or item.clientId is clientId

      itemIsInSet = idx isnt -1
      itemShouldBeInSet = item.matches(@_query.matchers())

      if itemIsInSet and not itemShouldBeInSet
        # remove the item
        @_lastResultSet.splice(idx, 1)
        status.setModified = true

      else if itemShouldBeInSet and not itemIsInSet
        # insert the item, re-sort if a sort order is defined
        if sortDescriptors.length > 0
          sortNecessary = true
        @_lastResultSet.push(item)
        status.setModified = true

      else if itemIsInSet
        # update the item in the set, re-sort if a sort attribute's value has changed
        if @_itemSortOrderHasChanged(@_lastResultSet[idx], item)
          sortNecessary = true
        @_lastResultSet[idx] = item
        status.setModified = true

    if sortNecessary
      @_resortResultSet()

    if sortNecessary and @_itemOnEdgeHasChanged(oldSetInfo)
      status.setFetchRequired = true

    # If items have been added, truncate the result set to the requested length
    if @_lastResultSet.length > @_limit
      @_lastResultSet.length = @_limit

    hadMaxItems = oldSetInfo.length is @_limit
    hasLostItems = @_lastResultSet.length < oldSetInfo.length

    if hadMaxItems and hasLostItems
      # Ex: We asked for 20 items and had 20 items. Now we have 19 items.
      # We need to pull a nw item to fill slot #20.
      status.setFetchRequired = true

    status

  _itemOnEdgeHasChanged: (oldSetInfo) ->
    hasPrecedingItems = @_offset > 0
    hasChangedStartItem = oldSetInfo.startItem isnt @_lastResultSet[0]

    if hasPrecedingItems and hasChangedStartItem
      # We've changed the identity of the item at index zero. We have no way
      # of knowing if it would still sort at this position, or if another item
      # from earlier in the range should be at index zero.
      # Full re-fetch is necessary.
      return true

    hasTrailingItems = @_lastResultSet.length is @_limit
    hasChangedEndItem = oldSetInfo.endItem isnt @_lastResultSet[@_limit - 1]

    if hasTrailingItems and hasChangedEndItem
      # We've changed he last item in the set, and the set is at it's LIMIT length.
      # We have no way of knowing if the item should still be at this position
      # since we can't see the next item.
      # Full re-fetch is necessary.
      return true

  _itemSortOrderHasChanged: (old, updated) ->
    for descriptor in @_query.orderSortDescriptors()
      oldSortValue = old[descriptor.attr.modelKey]
      updatedSortValue = updated[descriptor.attr.modelKey]

      # http://stackoverflow.com/questions/4587060/determining-date-equality-in-javascript
      if not (oldSortValue >= updatedSortValue && oldSortValue <= updatedSortValue)
        return true

    return false

  _invokeCallbacks: =>
    set = [].concat(@_lastResultSet)
    resultForSet = @_query.formatResultObjects(set)
    @_callbacks.forEach (callback) =>
      callback(resultForSet)

  _invokeCallback: (callback) =>
    set = [].concat(@_lastResultSet)
    resultForSet = @_query.formatResultObjects(set)
    callback(resultForSet)

module.exports = QuerySubscription
