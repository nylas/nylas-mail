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
    @listenTo NamespaceStore, @_onNamespaceChanged

    @_refreshCacheFromDB()
    @_onNamespaceChanged()

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

  categoryLabel: -> @_categoryLabel

  # It's possible for this to return `null`. For example, Gmail likely
  # doesn't have an `archive` label.
  getStandardCategory: (name) ->
    if not name in @standardCategories
      throw new Error("'#{name}' is not a standard category")
    return _.findWhere @_categoryCache, {name}

  _onDBChanged: (change) ->
    return unless @_klass and change?.objectClass == @_klass.name
    @_refreshCacheFromDB()

  _refreshDBFromAPI: ->
    NylasAPI.getCollection @_namespace.id, @_endpoint

  _refreshCacheFromDB: ->
    return unless @_klass
    DatabaseStore.findAll(@_klass).then (categories=[]) =>
      @_categoryCache = {}
      @_categoryCache[category.id] = category for category in categories
      @trigger()

  _onNamespaceChanged: ->
    @_namespace = NamespaceStore.current()
    return unless @_namespace

    if @_namespace.usesFolders()
      @_klass = Folder
      @_endpoint = "folders"
      @_categoryLabel = "Folders"
    else if @_namespace.usesLabels()
      @_klass = Label
      @_endpoint = "labels"
      @_categoryLabel = "Labels"
    else
      throw new Error("Invalid organizationUnit")

    @_refreshDBFromAPI()

module.exports = new CategoryStore()
