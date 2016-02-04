NylasStore = require 'nylas-store'
_ = require 'underscore'
{Actions,
 AccountStore,
 ThreadCountsStore,
 WorkspaceStore,
 OutboxStore,
 FocusedPerspectiveStore,
 CategoryStore} = require 'nylas-exports'

SidebarSection = require './sidebar-section'
SidebarActions = require './sidebar-actions'

Sections = {
  "Standard",
  "User"
}

class SidebarStore extends NylasStore

  constructor: ->
    @_sections = {}
    @_sections[Sections.Standard] = {}
    @_sections[Sections.User] = []
    @_focusedAccounts = @accounts()
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
    @configSubscription = NylasEnv.config.onDidChange(
      'core.accountSidebarCollapsed',
      @_updateSections
    )
    return

  _onAccountsFocused: (accounts) =>
    Actions.focusDefaultMailboxPerspectiveForAccounts(accounts)
    @_focusedAccounts = accounts
    @_updateSections()

  _onAccountsChanged: =>
    @_focusedAccounts = AccountStore.accounts()
    @_updateSections()

  _onFocusedPerspectiveChanged: =>
    currentIds = _.pluck(@_focusedAccounts, 'id')
    newIds = FocusedPerspectiveStore.current().accountIds
    newIdsNotInCurrent = _.difference(newIds, currentIds).length > 0
    if newIdsNotInCurrent
      @_focusedAccounts = newIds.map (id) -> AccountStore.accountForId(id)
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
