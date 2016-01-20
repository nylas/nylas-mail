_ = require 'underscore'
NylasStore = require 'nylas-store'
WorkspaceStore = require './workspace-store'
AccountStore = require './account-store'
Account = require '../models/account'
MailboxPerspective = require '../../mailbox-perspective'
MenuHelpers = require '../../menu-helpers'
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
    @_setupFastAccountCommands()
    @_setupFastAccountMenu()

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

  _setupFastAccountCommands: ->
    commands = {}
    allKey = "application:select-account-0"
    commands[allKey] = => @_onFocusAccounts(AccountStore.accounts())
    [1..8].forEach (index) =>
      account = AccountStore.accounts()[index - 1]
      return unless account
      key = "application:select-account-#{index}"
      commands[key] = => @_onFocusAccounts([account])
    NylasEnv.commands.add('body', commands)

  _setupFastAccountMenu: ->
    windowMenu = _.find NylasEnv.menu.template, ({label}) -> MenuHelpers.normalizeLabel(label) is 'Window'
    return unless windowMenu
    submenu = _.reject windowMenu.submenu, (item) -> item.account
    return unless submenu
    idx = _.findIndex submenu, ({type}) -> type is 'separator'
    return unless idx > 0

    menuItems = [{
      label: 'All Accounts'
      command: "application:select-account-0"
      account: true
    }]
    menuItems = menuItems.concat AccountStore.accounts().map((item, idx) =>
      label: item.emailAddress,
      command: "application:select-account-#{idx + 1}",
      account: true
    )

    submenu.splice(idx + 1, 0, menuItems...)
    windowMenu.submenu = submenu
    NylasEnv.menu.update()

  # Public Methods

  current: =>
    @_current

module.exports = new FocusedPerspectiveStore()
