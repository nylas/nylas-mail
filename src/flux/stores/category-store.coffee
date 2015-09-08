_ = require 'underscore'
Label = require '../models/label'
Folder = require '../models/folder'
NylasAPI = require '../nylas-api'
NylasStore = require 'nylas-store'
DatabaseStore = require './database-store'
AccountStore = require './account-store'

class CategoryStore extends NylasStore
  constructor: ->
    @_categoryCache = {}
    @_standardCategories = []
    @_userCategories = []
    @_hiddenCategories = []

    @listenTo DatabaseStore, @_onDBChanged
    @listenTo AccountStore, @_refreshCacheFromDB
    atom.config.observe 'core.showImportant', => @_refreshCacheFromDB()

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

  LockedCategoryNames: [
    "sent"
  ]

  HiddenCategoryNames: [
    "sent"
    "drafts"
    "all"
    "archive"
    "starred"
    "important"
  ]

  AllMailName: "all"

  byId: (id) -> @_categoryCache[id]

  categoryLabel: ->
    account = AccountStore.current()
    return "Unknown" unless account

    if account.usesFolders()
      return "Folders"
    else if account.usesLabels()
      return "Labels"
    return "Unknown"

  categoryClass: ->
    account = AccountStore.current()
    return null unless account

    if account.usesFolders()
      return Folder
    else if account.usesLabels()
      return Label
    return null

  # Public: Returns an array of all the categories in the current account, both
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

  # Public: Returns all of the standard categories for the current account.
  #
  getStandardCategories: ->
    @_standardCategories

  getUnhiddenStandardCategories: ->
    @getStandardCategories().filter (c) ->
      not _.contains @HiddenCategoryNames, c.name

  getHiddenCategories: ->
    @_hiddenCategories

  # Public: Returns all of the categories that are not part of the standard
  # category set.
  #
  getUserCategories: ->
    @_userCategories

  _onDBChanged: (change) ->
    categoryClass = @categoryClass()
    return unless categoryClass

    if change and change.objectClass is categoryClass.name
      @_refreshCacheFromDB()

  _refreshCacheFromDB: ->
    categoryClass = @categoryClass()
    account = AccountStore.current()
    return unless categoryClass

    DatabaseStore.findAll(categoryClass).where(categoryClass.attributes.accountId.equal(account.id)).then (categories=[]) =>
      @_categoryCache = {}
      @_categoryCache[category.id] = category for category in categories

      # Compute user categories
      userCategories = _.reject _.values(@_categoryCache), (cat) =>
        cat.name in @StandardCategoryNames or cat.name in @HiddenCategoryNames
      userCategories = _.sortBy(userCategories, 'displayName')
      @_userCategories =  _.compact(userCategories)

      # Compute hidden categories
      @_hiddenCategories = _.filter _.values(@_categoryCache), (cat) =>
        cat.name in @HiddenCategoryNames

      # Compute standard categories
      # Single pass to create lookup table, single pass to get ordered array
      byStandardName = {}
      for key, val of @_categoryCache
        byStandardName[val.name] = val

      if not atom.config.get('core.showImportant')
        delete byStandardName['important']

      @_standardCategories = _.compact @StandardCategoryNames.map (name) =>
        byStandardName[name]

      @trigger()

module.exports = new CategoryStore()
