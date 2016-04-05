Reflux = require 'reflux'
_ = require 'underscore'
NylasStore = require 'nylas-store'
DatabaseStore = require './database-store'
Thread = require '../models/thread'

###
Are running two nested SELECT statements really the best option? Yup.
For a performance assessment of these queries and other options, see:
https://gist.github.com/bengotow/c8b5cd8989c9149ded56

Note: SUM(unread) works because unread is represented as an int: 0 or 1.
###

ReadCountsQuery = ->
  "SELECT * FROM `ThreadCounts`"

SetCountsQuery = ->
  """
  REPLACE INTO `ThreadCounts` (category_id, unread, total)
  SELECT
    `ThreadCategory`.`value` as category_id,
    SUM(unread) as unread,
    COUNT(*) as total
  FROM `Thread`
  INNER JOIN `ThreadCategory` ON `Thread`.`id` = `ThreadCategory`.`id`
  WHERE
    `Thread`.in_all_mail = 1
  GROUP BY `ThreadCategory`.`value`;
  """

UpdateCountsQuery = (objectIds, operator) ->
  objectIdsString = "'" + objectIds.join("','") +  "'"
  """
  REPLACE INTO `ThreadCounts` (category_id, unread, total)
  SELECT
    `ThreadCategory`.`value` as category_id,
    COALESCE((SELECT unread FROM `ThreadCounts` WHERE category_id = `ThreadCategory`.`value`), 0) #{operator} SUM(unread) as unread,
    COALESCE((SELECT total  FROM `ThreadCounts` WHERE category_id = `ThreadCategory`.`value`), 0) #{operator} COUNT(*) as total
  FROM `Thread`
  INNER JOIN `ThreadCategory` ON `Thread`.`id` = `ThreadCategory`.`id`
  WHERE
    `Thread`.id IN (#{objectIdsString}) AND
    `Thread`.in_all_mail = 1
  GROUP BY `ThreadCategory`.`value`
  """

class CategoryDatabaseMutationObserver
  beforeDatabaseChange: (query, {type, objects, objectIds, objectClass}) =>
    if objectClass is Thread.name
      query(UpdateCountsQuery(objectIds, '-'))
    else
      Promise.resolve()

  afterDatabaseChange: (query, {type, objects, objectIds, objectClass}, beforeResolveValue) =>
    if objectClass is Thread.name
      query(UpdateCountsQuery(objectIds, '+'))
    else
      Promise.resolve()

class ThreadCountsStore extends NylasStore
  CategoryDatabaseMutationObserver: CategoryDatabaseMutationObserver

  constructor: ->
    @_counts = {}
    @_observer = new CategoryDatabaseMutationObserver()
    DatabaseStore.addMutationHook(@_observer)

    if NylasEnv.isMainWindow()
      # For now, unread counts are only retrieved in the main window.
      @_onCountsChangedDebounced = _.throttle(@_onCountsChanged, 1000)
      DatabaseStore.listen (change) =>
        if change.objectClass is Thread.name
          @_onCountsChangedDebounced()
      @_onCountsChangedDebounced()

    if NylasEnv.isWorkWindow() and not NylasEnv.config.get('nylas.threadCountsValid')
      @reset()

  reset: =>
    countsStartTime = null
    DatabaseStore.inTransaction (t) =>
      countsStartTime = Date.now()
      DatabaseStore._query(SetCountsQuery())
    .then =>
      NylasEnv.config.set('nylas.threadCountsValid', true)
      console.log("Recomputed all thread counts in #{Date.now() - countsStartTime}ms")

  _onCountsChanged: =>
    DatabaseStore._query(ReadCountsQuery()).then (results) =>
      @_counts = {}

      foundNegative = false
      for {category_id, unread, total} in results
        @_counts[category_id] = {unread, total}
        if unread < 0 or total < 0
          foundNegative = true

      if foundNegative
        NylasEnv.reportError(new Error('Assertion Failure: Negative Count'))
        @reset()
        return

      @trigger()

  unreadCountForCategoryId: (catId) =>
    return null if @_counts[catId] is undefined
    @_counts[catId]['unread']

  totalCountForCategoryId: (catId) =>
    return null if @_counts[catId] is undefined
    @_counts[catId]['total']

module.exports = new ThreadCountsStore
