_ = require 'underscore'
NylasStore = require 'nylas-store'
AccountStore = require './account-store'
{StandardCategoryNames} = require '../models/category'
{Categories} = require 'nylas-observables'
Rx = require 'rx-lite'

_observables = (account) ->
  {accountId} = account
  categories = Categories.forAccount(account).sort()
  return {
    allCategories: categories
    userCategories: categories.categoryFilter((cat) -> cat.isUserCategory())
    hiddenCategories: categories.categoryFilter((cat) -> cat.isHiddenCategory())
    standardCategories: Categories.standardForAccount(account).sort()
  }

class CategoryStore extends NylasStore

  constructor: ->
    @_categoryCache = {}
    @_setupObservables(AccountStore.accounts())

    @listenTo AccountStore, @_onAccountsChanged

  byId: (id) -> @_categoryCache[id]

  # Public: Returns an array of all categories for an account, both
  # standard and user generated. The items returned by this function will be
  # either {Folder} or {Label} objects.
  #
  categories: (account) ->
    @_observables[account.id].allCategories.last()

  # Public: Returns all of the standard categories for the current account.
  #
  standardCategories: (account) ->
    @_observables[account.id].standardCategories.last()

  hiddenCategories: (account) ->
    @_observables[account.id].hiddenCategories.last()

  # Public: Returns all of the categories that are not part of the standard
  # category set.
  #
  userCategories: (account) ->
    @_observables[account.id].userCategories.last()


  # Public: Returns the Folder or Label object for a standard category name and
  # for a given account.
  # ('inbox', 'drafts', etc.) It's possible for this to return `null`.
  # For example, Gmail likely doesn't have an `archive` label.
  #
  getStandardCategory: (account, name) ->
    return null unless account?
    if not name in StandardCategoryNames
      throw new Error("'#{name}' is not a standard category")
    return _.findWhere @standardCategories(account), {name}

  # Public: Returns the Folder or Label object that should be used for "Archive"
  # actions. On Gmail, this is the "all" label. On providers using folders, it
  # returns any available "Archive" folder, or null if no such folder exists.
  #
  getArchiveCategory: (account) ->
    return null unless account
    if account.usesFolders()
      return @getStandardCategory(account, "archive")
    else
      return @getStandardCategory(account, "all")

  # Public: Returns the Folder or Label object taht should be used for
  # "Move to Trash", or null if no trash folder exists.
  #
  getTrashCategory: (account) ->
    @getStandardCategory(account, "trash")

  _onAccountsChanged: ->
    @_setupObservables(AccountStore.accounts())

  _onCategoriesChanged: (categories) =>
    return unless categories
    @_categoryCache = {}
    for category in categories
      @_categoryCache[category.id] = category
    @trigger()

  _setupObservables: (accounts) =>
    @_observables = {}
    accounts.forEach (account) =>
      @_observables[account.accountId] = _observables(account)

    @_disposable?.dispose()
    @_disposable = Categories.forAllAccounts().subscribe(@_onCategoriesChanged)

module.exports = new CategoryStore()
