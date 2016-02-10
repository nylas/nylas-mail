_ = require 'underscore'
NylasStore = require 'nylas-store'
AccountStore = require './account-store'
MailboxPerspective = require '../../mailbox-perspective'
CategoryStore = require './category-store'
Actions = require '../actions'

class FocusedPerspectiveStore extends NylasStore
  constructor: ->
    @_current = @_initCurrentPerspective(NylasEnv.savedState.perspective)

    @listenTo CategoryStore, @_onCategoryStoreChanged
    @listenTo Actions.focusMailboxPerspective, @_onFocusPerspective
    @listenTo Actions.focusDefaultMailboxPerspectiveForAccounts, @_onFocusAccounts

  _initCurrentPerspective: (savedPerspective, accounts = AccountStore.accounts()) =>
    if savedPerspective
      current = MailboxPerspective.fromJSON(savedPerspective)
      if current
        accountIds = _.pluck(accounts, 'id')
        accountIdsNotPresent = _.difference(current.accountIds, accountIds)
        current = null if accountIdsNotPresent.length > 0

    current ?= @_defaultPerspective()
    return current

  # Inbound Events

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
    @_setPerspective(perspective)

  _onFocusAccounts: (accountsOrIds) =>
    return unless accountsOrIds
    @_setPerspective(MailboxPerspective.forInbox(accountsOrIds))

  _defaultPerspective: (accounts = AccountStore.accounts()) ->
    return MailboxPerspective.forNothing() unless accounts.length > 0
    return MailboxPerspective.forInbox(accounts)

  _setPerspective: (perspective) ->
    return if perspective?.isEqual(@_current)
    NylasEnv.savedState.perspective = perspective.toJSON()
    @_current = perspective
    @trigger()

  # Public Methods

  current: =>
    @_current

module.exports = new FocusedPerspectiveStore()
