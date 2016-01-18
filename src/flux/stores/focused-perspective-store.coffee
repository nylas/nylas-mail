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
    @listenTo Actions.focusDefaultMailboxPerspectiveForAccount, @_onFocusAccount

    @_onCategoryStoreChanged()
    @_setupFastAccountCommands()
    @_setupFastAccountMenu()

  # Inbound Events

  _onAccountStoreChanged: ->
    @_setupFastAccountMenu()

  _onCategoryStoreChanged: ->
    if not @_current
      @_setPerspective(@_defaultPerspective())
    else
      account = @_current.account
      cats   = @_current.categories()
      catExists = (cat) -> CategoryStore.byId(cat.accountId, cat.id)

      if cats and not _.every(cats, catExists)
        @_setPerspective(@_defaultPerspective(account))

  _onFocusPerspective: (perspective) =>
    return if perspective.isEqual(@_current)
    if WorkspaceStore.Sheet.Threads
      Actions.selectRootSheet(WorkspaceStore.Sheet.Threads)
    @_setPerspective(perspective)

  _onFocusAccount: (accountId) =>
    account = AccountStore.accountForId(accountId) unless account instanceof Account
    return unless account
    category = CategoryStore.getStandardCategory(account, "inbox")
    return unless category
    @_setPerspective(MailboxPerspective.forCategory(category))

  _defaultPerspective: (account = AccountStore.accounts()[0]) ->
    return MailboxPerspective.forNothing() unless account
    category = CategoryStore.getStandardCategory(account, "inbox")
    return MailboxPerspective.forNothing() unless category
    return MailboxPerspective.forCategory(category)

  _setPerspective: (perspective) ->
    return if perspective?.isEqual(@_current)
    @_current = perspective
    @trigger()

  _setupFastAccountCommands: ->
    commands = {}
    [0..8].forEach (index) =>
      key = "application:select-account-#{index}"
      commands[key] = => @_onFocusAccount(AccountStore.accounts()[index])
    NylasEnv.commands.add('body', commands)

  _setupFastAccountMenu: ->
    windowMenu = _.find NylasEnv.menu.template, ({label}) -> MenuHelpers.normalizeLabel(label) is 'Window'
    return unless windowMenu
    submenu = _.reject windowMenu.submenu, (item) -> item.account
    return unless submenu
    idx = _.findIndex submenu, ({type}) -> type is 'separator'
    return unless idx > 0

    accountMenuItems = AccountStore.accounts().map (item, idx) =>
      {
        label: item.emailAddress,
        command: "application:select-account-#{idx}",
        account: true
      }

    submenu.splice(idx + 1, 0, accountMenuItems...)
    windowMenu.submenu = submenu
    NylasEnv.menu.update()

  # Public Methods

  current: =>
    @_current

module.exports = new FocusedPerspectiveStore()
