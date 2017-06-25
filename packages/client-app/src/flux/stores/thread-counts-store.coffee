_ = require 'underscore'
NylasStore = require 'nylas-store'
DatabaseStore = require('./database-store').default
Thread = require('../models/thread').default

class ThreadCountsStore extends NylasStore
  constructor: ->
    @_counts = {}

    if NylasEnv.isMainWindow()
      # For now, unread counts are only retrieved in the main window.
      @_onCountsChangedDebounced = _.throttle(@_onCountsChanged, 1000)
      DatabaseStore.listen (change) =>
        if change.objectClass is Thread.name
          @_onCountsChangedDebounced()
      @_onCountsChangedDebounced()

  _onCountsChanged: =>
    DatabaseStore._query("SELECT * FROM `ThreadCounts`").then (results) =>
      nextCounts = {}

      foundNegative = false
      for {categoryId, unread, total} in results
        nextCounts[categoryId] = {unread, total}
        if unread < 0 or total < 0
          foundNegative = true

      if foundNegative
        NylasEnv.reportError(new Error('Assertion Failure: Negative Count'))
        @reset()
        return

      if _.isEqual(nextCounts, @_counts)
        return

      @_counts = nextCounts
      @trigger()

  unreadCountForCategoryId: (catId) =>
    return null if @_counts[catId] is undefined
    @_counts[catId]['unread']

  totalCountForCategoryId: (catId) =>
    return null if @_counts[catId] is undefined
    @_counts[catId]['total']

module.exports = new ThreadCountsStore
