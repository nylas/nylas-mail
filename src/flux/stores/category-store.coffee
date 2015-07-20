_ = require 'underscore'
Label = require '../models/label'
Folder = require '../models/folder'
NylasAPI = require '../nylas-api'
NylasStore = require 'nylas-store'
DatabaseStore = require './database-store'
NamespaceStore = require './namespace-store'

class CategoryStore extends NylasStore
  constructor: ->
    @_categoryCache = {}
    @listenTo DatabaseStore, @_onDBChanged
    @listenTo NamespaceStore, @_refreshCacheFromDB
    @_refreshCacheFromDB()

  # We look for a few standard categories and display them in the Mailboxes
  # portion of the left sidebar. Note that these may not all be present on
  # a particular account.
  StandardCategoryNames: [
    "inbox"
    "important"
    "sent"
    "drafts"
    "all"
    "spam"
    "archive"
    "trash"
  ]

  AllMailName: "all"

  byId: (id) -> @_categoryCache[id]

  categoryLabel: ->
    namespace = NamespaceStore.current()
    return "Unknown" unless namespace

    if namespace.usesFolders()
      return "Folders"
    else if namespace.usesLabels()
      return "Labels"
    return "Unknown"

  categoryClass: ->
    namespace = NamespaceStore.current()
    return null unless namespace

    if namespace.usesFolders()
      return Folder
    else if namespace.usesLabels()
      return Label
    return null

  # Public: Returns an array of all the categories in the current namespace, both
  # standard and user generated. The items returned by this function will be
  # either {Folder} or {Label} objects.
  #
  getCategories: -> _.values @_categoryCache


  # Public: Returns the Folder or Label object for a standard category name.
  # ('inbox', 'drafts', etc.) It's possible for this to return `null`.
  # For example, Gmail likely doesn't have an `archive` label.
  #
  getStandardCategory: (name) ->
    if not name in @StandardCategoryNames
      throw new Error("'#{name}' is not a standard category")
    return _.findWhere @_categoryCache, {name}

  # Public: Returns all of the standard categories for the current namespace.
  #
  getStandardCategories: ->
    # Single pass to create lookup table, single pass to get ordered array
    byStandardName = {}
    for key, val of @_categoryCache
      byStandardName[val.name] = val
    _.compact @StandardCategoryNames.map (name) =>
      byStandardName[name]

  # Public: Returns all of the categories that are not part of the standard
  # category set.
  #
  getUserCategories: ->
    userCategories = _.reject _.values(@_categoryCache), (cat) =>
      cat.name in @StandardCategoryNames
    userCategories = _.sortBy(userCategories, 'displayName')
    userCategories

  _onDBChanged: (change) ->
    categoryClass = @categoryClass()
    return unless categoryClass

    if change and change.objectClass is categoryClass.name
      @_refreshCacheFromDB()

  _refreshCacheFromDB: ->
    categoryClass = @categoryClass()
    return unless categoryClass

    DatabaseStore.findAll(categoryClass).then (categories=[]) =>
      @_categoryCache = {}
      @_categoryCache[category.id] = category for category in categories
      @trigger()

module.exports = new CategoryStore()
