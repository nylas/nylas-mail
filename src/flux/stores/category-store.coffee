_ = require 'underscore'
NylasStore = require 'nylas-store'
AccountStore = require './account-store'
{StandardCategoryNames} = require '../models/category'
{Categories} = require 'nylas-observables'
Rx = require 'rx-lite'

class CategoryStore extends NylasStore

  constructor: ->
    @_categoryCache = {}
    @_registerObservables(AccountStore.accounts())

    @listenTo AccountStore, @_onAccountsChanged

  byId: (account, categoryId) -> @categories(account)[categoryId]

  # Public: Returns an array of all categories for an account, both
  # standard and user generated. The items returned by this function will be
  # either {Folder} or {Label} objects.
  #
  categories: (account) ->
    if account
      @_categoryCache[account.id] ? {}
    else
      _.flatten(_.values(@_categoryCache))

  # Public: Returns all of the standard categories for the current account.
  #
  standardCategories: (account) ->
    _.values(@categories(account)).filter (cat) -> cat.isStandardCategory()

  hiddenCategories: (account) ->
    _.values(@categories(account)).filter (cat) -> cat.isHiddenCategory()

  # Public: Returns all of the categories that are not part of the standard
  # category set.
  #
  userCategories: (account) ->
    _.values(@categories(account)).filter (cat) -> cat.isUserCategory()

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
    @_registerObservables(AccountStore.accounts())

  _onCategoriesChanged: (accountId, categories) =>
    return unless categories
    @_categoryCache[accountId] = {}
    for category in categories
      @_categoryCache[accountId][category.id] = category
    @trigger()

  _registerObservables: (accounts) =>
    @_disposables ?= []
    @_disposables.forEach (disp) -> disp.dispose()
    @_disposables = accounts.map (account) =>
      Categories.forAccount(account)
        .subscribe(@_onCategoriesChanged.bind(@, account.id))

module.exports = new CategoryStore()
