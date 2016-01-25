_ = require 'underscore'
Rx = require 'rx-lite'
DatabaseStore = require './database-store'
Message = require '../models/message'
QuerySubscriptionPool = require '../models/query-subscription-pool'
QuerySubscription = require '../models/query-subscription'
MutableQuerySubscription = require '../models/mutable-query-subscription'
ListDataSource = require './list-data-source'

###
This class takes an observable which vends QueryResultSets and adapts it so that
you can make it the data source of a MultiselectList.

When the MultiselectList is refactored to take an Observable, this class should
go away!
###
class ObservableListDataSource extends ListDataSource

  constructor: ($resultSetObservable, @_setRetainedRange) ->
    super
    @_countEstimate = -1
    @_resultSet = null
    @_resultDesiredLast = null

    @_subscription = $resultSetObservable.subscribe (nextResultSet) =>
      if nextResultSet.range().end is @_resultDesiredLast
        @_countEstimate = Math.max(@_countEstimate, nextResultSet.range().end + 1)
      else
        @_countEstimate = nextResultSet.range().end

      previousResultSet = @_resultSet
      @_resultSet = nextResultSet

      # If the result set is derived from a query, remove any items in the selection
      # that do not match the query. This ensures that items "removed from the view"
      # are removed from the selection.
      query = nextResultSet.query()
      @selection.removeItemsNotMatching(query.matchers()) if query

      @trigger({previous: previousResultSet, next: nextResultSet})

  setRetainedRange: ({start, end}) ->
    @_resultDesiredLast = end
    @_setRetainedRange({start, end})

  # Retrieving Data

  count: ->
    @_countEstimate

  loaded: ->
    @_resultSet isnt null

  empty: =>
    not @_resultSet or @_resultSet.empty()

  get: (offset) =>
    return null unless @_resultSet
    @_resultSet.modelAtOffset(offset)

  getById: (id) ->
    @_resultSet.modelWithId(id)

  indexOfId: (id) ->
    return -1 unless @_resultSet and id
    @_resultSet.offsetOfId(id)

  itemsCurrentlyInViewMatching: (matchFn) ->
    return [] unless @_resultSet
    @_resultSet.models().filter(matchFn)

  cleanup: ->
    @_subscription?.dispose()
    super


module.exports = ObservableListDataSource
