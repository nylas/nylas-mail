Reflux = require 'reflux'
Rx = require 'rx-lite'
_ = require 'underscore'
NylasStore = require 'nylas-store'
CategoryStore = require './category-store'
AccountStore = require './account-store'
DatabaseStore = require './database-store'
Actions = require '../actions'
Thread = require '../models/thread'
Category = require '../models/category'
WindowBridge = require '../../window-bridge'

JSONBlobKey = 'UnreadCounts-V2'

class CategoryDatabaseMutationObserver
  constructor: (@_countsDidChange) ->

  beforeDatabaseChange: (query, {type, objects, objectIds, objectClass}) =>
    if objectClass is Thread.name
      idString = "'" + objectIds.join("','") +  "'"
      query("SELECT `Thread`.id as id, `Thread-Category`.`value` as catId FROM `Thread` INNER JOIN `Thread-Category` ON `Thread`.`id` = `Thread-Category`.`id` WHERE `Thread`.id IN (#{idString}) AND `Thread`.unread = 1", [])
      .then (categoryData) =>
        categories = {}
        for {id, catId} in categoryData
          categories[catId] ?= 0
          categories[catId] -= 1
        Promise.resolve({categories})
    else
      Promise.resolve()

  afterDatabaseChange: (query, {type, objects, objectIds, objectClass}, beforeResolveValue) =>
    if objectClass is Thread.name
      {categories} = beforeResolveValue

      if type is 'persist'
        for thread in objects
          continue unless thread.unread
          for collection in ['labels', 'folders']
            if thread[collection]
              for cat in thread[collection]
                categories[cat.id] ?= 0
                categories[cat.id] += 1

      for key, val of categories
        delete categories[key] if val is 0

      if Object.keys(categories).length > 0
        @_countsDidChange(categories)

    Promise.resolve()


class ThreadCountsStore extends NylasStore
  CategoryDatabaseMutationObserver: CategoryDatabaseMutationObserver
  JSONBlobKey: JSONBlobKey

  constructor: ->
    @_counts = {}
    @_deltas = {}
    @_saveCountsSoon ?= _.throttle(@_saveCounts, 1000)

    @_observer = new CategoryDatabaseMutationObserver(@_onCountsChanged)
    DatabaseStore.addMutationHook(@_observer)

    if NylasEnv.isWorkWindow()
      DatabaseStore.findJSONBlob(JSONBlobKey).then(@_onCountsBlobRead)
      Rx.Observable.fromQuery(DatabaseStore.findAll(Category)).subscribe (categories) =>
        @_categories = [].concat(categories)
        @_fetchCountsMissing()

    else
      query = DatabaseStore.findJSONBlob(JSONBlobKey)
      Rx.Observable.fromQuery(query).subscribe(@_onCountsBlobRead)

  unreadCountForCategoryId: (catId) =>
    return null if @_counts[catId] is undefined
    @_counts[catId] + (@_deltas[catId] || 0)

  unreadCounts: =>
    @_counts

  _onCountsChanged: (metadata) =>
    if not NylasEnv.isWorkWindow()
      WindowBridge.runInWorkWindow("ThreadCountsStore", "_onCountsChanged", [metadata])
      return

    for catId, unread of metadata
      @_deltas[catId] ?= 0
      @_deltas[catId] += unread
    @_saveCountsSoon()

  _onCountsBlobRead: (json) =>
    @_counts = json ? {}
    @trigger()

  # Fetch a count, populate it in the cache, and then call ourselves to
  # populate the next missing count.
  _fetchCountsMissing: =>
    # Find a category missing a count
    category = _.find @_categories, (cat) => !@_counts[cat.id]?
    return unless category

    # Reset the delta for the category, since we're about to fetch absolute count
    @_deltas[category.id] = 0

    @_fetchCountForCategory(category).then (unread) =>
      # Only apply the count if we know it's still correct. If we've detected changes
      # during the query, we can't know whether `unread` includes those or not.
      # Just run the count query again in a few moments.
      if @_deltas[category.id] is 0
        @_counts[category.id] = unread

      # We defer for a while - this means populating all the counts can take a while,
      # but we don't want to flood the db with expensive SELECT COUNT queries.
      _.delay(@_fetchCountsMissing, 3000)
      @_saveCountsSoon()

    # This method is not intended to return a promise and it
    # could cause strange chaining.
    return null

  _saveCounts: =>
    for key, count of @_deltas
      continue if @_counts[key] is undefined
      @_counts[key] += count
      delete @_deltas[key]

    DatabaseStore.inTransaction (t) =>
      t.persistJSONBlob(JSONBlobKey, @_counts)
    @trigger()

  _fetchCountForCategory: (cat) =>
    DatabaseStore.count(Thread, [
      Thread.attributes.categories.contains(cat.id),
      Thread.attributes.accountId.equal(cat.accountId),
      Thread.attributes.unread.equal(true),
    ])

module.exports = new ThreadCountsStore
