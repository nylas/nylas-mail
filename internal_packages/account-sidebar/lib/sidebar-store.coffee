_ = require 'underscore'
NylasStore = require 'nylas-store'
{Actions,
 AccountStore,
 ThreadCountsStore,
 WorkspaceStore,
 OutboxStore,
 FocusedPerspectiveStore,
 CategoryStore} = require 'nylas-exports'

SidebarSection = require './sidebar-section'
SidebarActions = require './sidebar-actions'
AccountCommands = require './account-commands'

Sections = {
  "Standard",
  "User"
}

class SidebarStore extends NylasStore

  constructor: ->
    NylasEnv.savedState.sidebarKeysCollapsed ?= {}
    NylasEnv.savedState.shouldRefocusSidebarAccounts ?= true

    @_sections = {}
    @_sections[Sections.Standard] = {}
    @_sections[Sections.User] = []
    @_focusedAccounts = FocusedPerspectiveStore.current().accountIds.map (id) ->
      AccountStore.accountForId(id)
    @_registerCommands()
    @_registerMenuItems()
    @_registerListeners()
    @_updateSections()

  accounts: ->
    AccountStore.accounts()

  focusedAccounts: ->
    @_focusedAccounts

  standardSection: ->
    @_sections[Sections.Standard]

  userSections: ->
    @_sections[Sections.User]

  _registerListeners: ->
    @listenTo Actions.setCollapsedSidebarItem, @_onSetCollapsedByName
    @listenTo SidebarActions.setKeyCollapsed, @_onSetCollapsedByKey
    @listenTo SidebarActions.focusAccounts, @_onAccountsFocused
    @listenTo AccountStore, @_onAccountsChanged
    @listenTo FocusedPerspectiveStore, @_onFocusedPerspectiveChanged
    @listenTo WorkspaceStore, @_updateSections
    @listenTo OutboxStore, @_updateSections
    @listenTo ThreadCountsStore, @_updateSections
    @listenTo CategoryStore, @_updateSections

    @configSubscription = NylasEnv.config.onDidChange(
      'core.workspace.showUnreadForAllCategories',
      @_updateSections
    )

    return

  _onSetCollapsedByKey: (itemKey, collapsed) =>
    currentValue = NylasEnv.savedState.sidebarKeysCollapsed[itemKey]
    if currentValue isnt collapsed
      NylasEnv.savedState.sidebarKeysCollapsed[itemKey] = collapsed
      @_updateSections()

  _onSetCollapsedByName: (itemName, collapsed) =>
    item = _.findWhere(@standardSection().items, {name: itemName})
    if not item
      for section in @userSections()
        item = _.findWhere(section.items, {name: itemName})
        break if item
    return unless item
    @_onSetCollapsedByKey(item.id, collapsed)

  _registerCommands: (accounts = AccountStore.accounts()) =>
    AccountCommands.registerCommands(accounts)

  _registerMenuItems: (accounts = AccountStore.accounts()) =>
    AccountCommands.registerMenuItems(accounts, @_focusedAccounts)

  _onAccountsFocused: (accounts) =>
    Actions.focusDefaultMailboxPerspectiveForAccounts(accounts)
    @_focusedAccounts = accounts
    @_registerMenuItems()
    @_updateSections()

  _onAccountsChanged: =>
    accounts = AccountStore.accounts()
    @_focusedAccounts = accounts
    @_registerCommands()
    @_registerMenuItems()
    @_updateSections()

  _onFocusedPerspectiveChanged: =>
    currentIds = _.pluck(@_focusedAccounts, 'id')
    newIds = FocusedPerspectiveStore.current().accountIds
    # TODO get rid of this nasty global state
    if NylasEnv.savedState.shouldRefocusSidebarAccounts is true
      @_focusedAccounts = newIds.map (id) -> AccountStore.accountForId(id)
      @_registerMenuItems()
    @_updateSections()

  _updateSections: =>
    accounts = @_focusedAccounts
    multiAccount = accounts.length > 1

    @_sections[Sections.Standard] = SidebarSection.standardSectionForAccounts(accounts)
    @_sections[Sections.User] = accounts.map (acc) ->
      opts = {}
      if multiAccount
        opts.title = acc.label
        opts.collapsible = true
      SidebarSection.forUserCategories(acc, opts)
    @trigger()


module.exports = new SidebarStore()
