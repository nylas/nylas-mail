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

    @_sections = {}
    @_sections[Sections.Standard] = {}
    @_sections[Sections.User] = []
    @_registerCommands()
    @_registerMenuItems()
    @_registerListeners()
    @_updateSections()

  accounts: ->
    AccountStore.accounts()

  sidebarAccountIds: ->
    FocusedPerspectiveStore.sidebarAccountIds()

  standardSection: ->
    @_sections[Sections.Standard]

  userSections: ->
    @_sections[Sections.User]

  _registerListeners: ->
    @listenTo Actions.setCollapsedSidebarItem, @_onSetCollapsedByName
    @listenTo SidebarActions.setKeyCollapsed, @_onSetCollapsedByKey
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
    AccountCommands.registerMenuItems(accounts, FocusedPerspectiveStore.sidebarAccountIds())

  # TODO Refactor this
  # Listen to changes on the account store only for when the account label
  # or order changes. When accounts or added or removed, those changes will
  # come in through the FocusedPerspectiveStore
  _onAccountsChanged: =>
    @_updateSections()

  # TODO Refactor this
  # The FocusedPerspectiveStore tells this store the accounts that should be
  # displayed in the sidebar (i.e. unified inbox vs single account) and will
  # trigger whenever an account is added or removed, as well as when a
  # perspective is focused.
  # However, when udpating the SidebarSections, we also depend on the actual
  # accounts in the AccountStore. The problem is that the FocusedPerspectiveStore
  # triggers before the AccountStore is actually updated, so we need to wait for
  # the AccountStore to get updated (via `defer`) before updateing our sidebar
  # sections
  _onFocusedPerspectiveChanged: =>
    _.defer =>
      @_registerCommands()
      @_registerMenuItems()
      @_updateSections()

  _updateSections: =>
    accounts = FocusedPerspectiveStore.sidebarAccountIds()
      .map((id) => AccountStore.accountForId(id))
      .filter((a) => !!a)

    return if accounts.length is 0
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
