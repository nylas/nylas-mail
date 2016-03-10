_ = require 'underscore'
NylasStore = require 'nylas-store'
AccountStore = require './account-store'
Account = require '../models/account'
{StandardCategoryNames} = require '../models/category'
{Categories} = require 'nylas-observables'
Rx = require 'rx-lite'

asAccount = (a) ->
  throw new Error("You must pass an Account or Account Id") unless a
  if a instanceof Account then a else AccountStore.accountForId(a)

asAccountId = (a) ->
  throw new Error("You must pass an Account or Account Id") unless a
  if a instanceof Account then a.id else a

class CategoryStore extends NylasStore

  constructor: ->
    @_categoryCache = {}
    @_standardCategories = {}
    @_userCategories = {}
    @_hiddenCategories = {}

    NylasEnv.config.onDidChange 'core.workspace.showImportant', =>
      return unless @_categoryResult
      @_onCategoriesChanged(@_categoryResult)

    Categories
      .forAllAccounts()
      .sort()
      .subscribe(@_onCategoriesChanged)

  byId: (accountOrId, categoryId) ->
    categories = @_categoryCache[asAccountId(accountOrId)] ? {}
    categories[categoryId]

  # Public: Returns an array of all categories for an account, both
  # standard and user generated. The items returned by this function will be
  # either {Folder} or {Label} objects.
  #
  categories: (accountOrId = null) ->
    if accountOrId
      _.values(@_categoryCache[asAccountId(accountOrId)]) ? []
    else
      all = []
      for accountId, categories of @_categoryCache
        all = all.concat(_.values(categories))
      all

  # Public: Returns all of the standard categories for the given account.
  #
  standardCategories: (accountOrId) ->
    @_standardCategories[asAccountId(accountOrId)] ? []

  hiddenCategories: (accountOrId) ->
    @_hiddenCategories[asAccountId(accountOrId)] ? []

  # Public: Returns all of the categories that are not part of the standard
  # category set.
  #
  userCategories: (accountOrId) ->
    @_userCategories[asAccountId(accountOrId)] ? []

  # Public: Returns the Folder or Label object for a standard category name and
  # for a given account.
  # ('inbox', 'drafts', etc.) It's possible for this to return `null`.
  # For example, Gmail likely doesn't have an `archive` label.
  #
  getStandardCategory: (accountOrId, name) =>
    return null unless accountOrId

    unless name in StandardCategoryNames
      throw new Error("'#{name}' is not a standard category")

    return _.findWhere(@_standardCategories[asAccountId(accountOrId)], {name})

  # Public: Returns the set of all standard categories that match the given
  # names for each of the provided accounts
  getStandardCategories: (accountsOrIds, names...) =>
    if Array.isArray(accountsOrIds)
      res = []
      for accOrId in accountsOrIds
        cats = names.map((name) => @getStandardCategory(accOrId, name))
        res = res.concat(_.compact(cats))
      res
    else
      names.map((name) => @getStandardCategory(accountsOrIds, name))

  # Public: Returns the Folder or Label object that should be used for "Archive"
  # actions. On Gmail, this is the "all" label. On providers using folders, it
  # returns any available "Archive" folder, or null if no such folder exists.
  #
  getArchiveCategory: (accountOrId) =>
    return null unless accountOrId
    account = asAccount(accountOrId)
    return null unless account

    if account.usesFolders()
      return @getStandardCategory(account.id, "archive")
    else
      return @getStandardCategory(account.id, "all")

  # Public: Returns the Folder or Label object that should be used for
  # the inbox or null if it doesn't exist
  #
  getInboxCategory: (accountOrId) =>
    @getStandardCategory(accountOrId, "inbox")

  # Public: Returns the Folder or Label object that should be used for
  # "Move to Trash", or null if no trash folder exists.
  #
  getTrashCategory: (accountOrId) =>
    @getStandardCategory(accountOrId, "trash")

  _onCategoriesChanged: (categories) =>
    @_categoryResult = categories
    @_categoryCache = {}
    for cat in categories
      @_categoryCache[cat.accountId] ?= {}
      @_categoryCache[cat.accountId][cat.id] = cat

    filteredByAccount = (fn) ->
      result = {}
      for cat in categories
        continue unless fn(cat)
        result[cat.accountId] ?= []
        result[cat.accountId].push(cat)
      result

    @_standardCategories = filteredByAccount (cat) -> cat.isStandardCategory()
    @_userCategories = filteredByAccount (cat) -> cat.isUserCategory()
    @_hiddenCategories = filteredByAccount (cat) -> cat.isHiddenCategory()

    # Ensure standard categories are always sorted in the correct order
    for accountId, items of @_standardCategories
      @_standardCategories[accountId].sort (a, b) ->
        StandardCategoryNames.indexOf(a.name) - StandardCategoryNames.indexOf(b.name)

    @trigger()

module.exports = new CategoryStore()
