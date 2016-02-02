NylasStore = require 'nylas-store'
_ = require 'underscore'
{Actions,
 AccountStore,
 ThreadCountsStore,
 WorkspaceStore,
 FocusedPerspectiveStore,
 CategoryStore} = require 'nylas-exports'

SidebarSection = require './sidebar-section'

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
    @listenTo Actions.focusSidebarAccounts, @_onAccountsFocused
    @listenTo AccountStore, @_onAccountsChanged
    @listenTo FocusedPerspectiveStore, @_updateSections
    @listenTo WorkspaceStore, @_updateSections
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
    @_focusedAccounts = accounts
    @_updateSections()

  _onAccountsChanged: =>
    @_focusedAccounts = AccountStore.accounts()
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
