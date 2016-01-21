_ = require 'underscore'
NylasStore = require 'nylas-store'
WorkspaceStore = require './workspace-store'
AccountStore = require './account-store'
MailboxPerspective = require '../../mailbox-perspective'
CategoryStore = require './category-store'
Actions = require '../actions'

class FocusedPerspectiveStore extends NylasStore
  constructor: ->
    @_current = @_defaultPerspective()

    @listenTo CategoryStore, @_onCategoryStoreChanged
    @listenTo AccountStore, @_onAccountStoreChanged

    @listenTo Actions.focusMailboxPerspective, @_onFocusPerspective
    @listenTo Actions.focusDefaultMailboxPerspectiveForAccounts, @_onFocusAccounts

    @_onCategoryStoreChanged()

  # Inbound Events

  _onAccountStoreChanged: ->
    @_setupFastAccountMenu()

  _onCategoryStoreChanged: ->
    if @_current.isEqual(MailboxPerspective.forNothing())
      @_setPerspective(@_defaultPerspective())
    else
      accountIds = @_current.accountIds
      categories = @_current.categories()
      catExists  = (cat) -> CategoryStore.byId(cat.accountId, cat.id)
      categoryHasBeenDeleted = categories and not _.every(categories, catExists)

    if categoryHasBeenDeleted
      @_setPerspective(@_defaultPerspective(accountIds))

  _onFocusPerspective: (perspective) =>
    return if perspective.isEqual(@_current)
    if WorkspaceStore.Sheet.Threads
      Actions.selectRootSheet(WorkspaceStore.Sheet.Threads)
    @_setPerspective(perspective)

  _onFocusAccounts: (accountsOrIds) =>
    return unless accountsOrIds
    @_setPerspective(MailboxPerspective.forInbox(accountsOrIds))

  _defaultPerspective: (accounts = AccountStore.accounts()) ->
    return MailboxPerspective.forNothing() unless accounts.length > 0
    return MailboxPerspective.forInbox(accounts)

  _setPerspective: (perspective) ->
    return if perspective?.isEqual(@_current)
    @_current = perspective
    @trigger()

  # Public Methods

  current: =>
    @_current

module.exports = new FocusedPerspectiveStore()
