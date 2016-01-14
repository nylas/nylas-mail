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

    $resultSetObservable.subscribe (nextResultSet) =>
      if nextResultSet.range().end is @_resultDesiredLast
        @_countEstimate = Math.max(@_countEstimate, nextResultSet.range().end + 1)
      else
        @_countEstimate = nextResultSet.range().end

      previousResultSet = @_resultSet
      @_resultSet = nextResultSet

      @selection.updateModelReferences(@_resultSet.models())
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


module.exports = ObservableListDataSource
