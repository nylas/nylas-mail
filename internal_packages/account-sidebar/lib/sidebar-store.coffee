NylasStore = require 'nylas-store'
_ = require 'underscore'
{DatabaseStore,
 AccountStore,
 ThreadCountsStore,
 DraftCountStore,
 WorkspaceStore,
 MailboxPerspective,
 FocusedPerspectiveStore,
 DestroyCategoryTask,
 CategoryHelpers,
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
    @_registerListeners()
    @_updateSections()

  accounts: ->
    AccountStore.accounts()

  focusedAccounts: ->
    accountIds = FocusedPerspectiveStore.current().accountIds
    accountIds.map((accId) -> AccountStore.accountForId(accId))

  standardSection: ->
    @_sections[Sections.Standard]

  userSections: ->
    @_sections[Sections.User]

  _registerListeners: ->
    @listenTo AccountStore, @_updateSections
    @listenTo WorkspaceStore, @_updateSections
    @listenTo ThreadCountsStore, @_updateSections
    @listenTo DraftCountStore, @_updateSections
    @listenTo CategoryStore, @_updateSections
    @listenTo FocusedPerspectiveStore, @_updateSections
    @configSubscription = NylasEnv.config.observe(
      'core.workspace.showUnreadForAllCategories',
      @_updateSections
    )
    @configSubscription = NylasEnv.config.observe(
      'core.accountSidebarCollapsed',
      @_updateSections
    )
    return

  _updateSections: =>
    accounts = @focusedAccounts()

    @_sections[Sections.Standard] = SidebarSection.standardSectionForAccounts(accounts)
    @_sections[Sections.User] = accounts.map (acc) ->
      SidebarSection.forUserCategories(acc)
    @trigger()


module.exports = new SidebarStore()
