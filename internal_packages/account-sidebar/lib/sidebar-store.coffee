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
SidebarActions = require './sidebar-actions'

Sections = {
  "Standard",
  "User"
}

class SidebarStore extends NylasStore

  constructor: ->
    @_sections = {}
    # @_account = AccountStore.accounts()[0]
    @_account = FocusedPerspectiveStore.current().account
    @_registerListeners()
    @_updateSections()

  standardSection: ->
    @_sections[Sections.Standard]

  userSections: ->
    @_sections[Sections.User]

  _registerListeners: ->
    @listenTo SidebarActions.selectAccount, @_onAccountSelected
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

  _onAccountSelected: (account) =>
    if @_account isnt account
      @_account = account
      @_updateSections()

  _updateSections: =>
    accounts = if @_account? then [@_account] else AccountStore.accounts()
    @_sections[Sections.Standard] = SidebarSection.standardSectionForAccounts(accounts)
    @_sections[Sections.User] = accounts.map (acc) ->
      SidebarSection.forUserCategories(acc)
    @trigger()


module.exports = new SidebarStore()
