Reflux = require 'reflux'
_ = require 'underscore'
NylasStore = require 'nylas-store'
CategoryStore = require './category-store'
AccountStore = require './account-store'
DatabaseStore = require './database-store'
Actions = require '../actions'
Thread = require '../models/thread'
Folder = require '../models/folder'
Label = require '../models/label'
WindowBridge = require '../../window-bridge'

JSONObjectKey = 'UnreadCounts-V0'

class CategoryDatabaseMutationObserver
  constructor: (@_countsDidChange) ->

  beforeDatabaseChange: (query, models, ids) =>
    if models[0].constructor.name is 'Thread'
      idString = "'" + ids.join("','") +  "'"
      Promise.props
        labelData: query("SELECT `Thread`.id as id, `Thread-Label`.`value` as catId FROM `Thread` INNER JOIN `Thread-Label` ON `Thread`.`id` = `Thread-Label`.`id` WHERE `Thread`.id IN (#{idString}) AND `Thread`.unread = 1", [])
        folderData: query("SELECT `Thread`.id as id, `Thread-Folder`.`value` as catId FROM `Thread` INNER JOIN `Thread-Folder` ON `Thread`.`id` = `Thread-Folder`.`id` WHERE `Thread`.id IN (#{idString}) AND `Thread`.unread = 1", [])
      .then ({labelData, folderData}) =>
        categories = {}
        for collection in [labelData, folderData]
          for {id, catId} in collection
            categories[catId] ?= 0
            categories[catId] -= 1
        Promise.resolve({categories})
    else
      Promise.resolve()

  afterDatabaseChange: (query, models, ids, beforeResolveValue) =>
    if models[0].constructor.name is 'Thread'
      {categories} = beforeResolveValue
      for thread in models
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
  JSONObjectKey: JSONObjectKey

  constructor: ->
    @_counts = {}
    @_deltas = {}
    @_categories = []
    @_saveCountsSoon ?= _.throttle(@_saveCounts, 1000)

    @listenTo DatabaseStore, @_onDatabaseChanged
    DatabaseStore.findJSONObject(JSONObjectKey).then (json) =>
      @_counts = json ? {}
      @trigger()

    @_observer = new CategoryDatabaseMutationObserver(@_onCountsChanged)
    DatabaseStore.addMutationHook(@_observer)

    if NylasEnv.isWorkWindow()
      @_loadCategories().then =>
        @_fetchCountsMissing()

  unreadCountForCategoryId: (catId) =>
    return null if @_counts[catId] is undefined
    @_counts[catId] + (@_deltas[catId] || 0)

  unreadCounts: =>
    @_counts

  _onDatabaseChanged: (change) =>
    if NylasEnv.isWorkWindow()
      if change.objectClass in [Folder.name, Label.name]
        for obj in change.objects
          objIdx = _.findIndex @_categories, (cat) -> cat.id is obj.id
          if objIdx isnt -1
            @_categories[objIdx] = obj
          else
            @_categories.push(obj)
        @_fetchCountsMissing()

    else if change.objectClass is 'JSONObject' and change.objects[0].key is JSONObjectKey
      @_counts = change.objects[0].json ? {}
      @trigger()

  _onCountsChanged: (metadata) =>
    if not NylasEnv.isWorkWindow()
      WindowBridge.runInWorkWindow("ThreadCountsStore", "_onCountsChanged", [metadata])
      return

    for catId, unread of metadata
      @_deltas[catId] ?= 0
      @_deltas[catId] += unread
    @_saveCountsSoon()

  _loadCategories: =>
    Promise.props({
      folders: DatabaseStore.findAll(Folder)
      labels: DatabaseStore.findAll(Label)
    }).then ({folders, labels}) =>
      @_categories = [].concat(folders, labels)
      Promise.resolve()

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

    DatabaseStore.persistJSONObject(JSONObjectKey, @_counts)
    @trigger()

  _fetchCountForCategory: (cat) =>
    if cat instanceof Label
      categoryAttribute = Thread.attributes.labels
    else if cat instanceof Folder
      categoryAttribute = Thread.attributes.folders
    else
      throw new Error("Unexpected category class")

    DatabaseStore.count(Thread, [
      Thread.attributes.accountId.equal(cat.accountId),
      Thread.attributes.unread.equal(true),
      categoryAttribute.contains(cat.id)
    ])

module.exports = new ThreadCountsStore
