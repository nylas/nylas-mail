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

  # and labels: an extended version of [RFC-6154]
  # (http://tools.ietf.org/html/rfc6154), returned as the name of the
  # folder or label
  standardCategories: [
    "inbox"
    "all"
    "trash"
    "archive"
    "drafts"
    "sent"
    "spam"
    "important"
  ]

  AllMailName: "all"

  byId: (id) -> @_categoryCache[id]

  categories: -> _.values @_categoryCache

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

  # It's possible for this to return `null`. For example, Gmail likely
  # doesn't have an `archive` label.
  getStandardCategory: (name) ->
    if not name in @standardCategories
      throw new Error("'#{name}' is not a standard category")
    return _.findWhere @_categoryCache, {name}

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
