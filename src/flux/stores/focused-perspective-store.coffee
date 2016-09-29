_ = require 'underscore'
NylasStore = require 'nylas-store'
AccountStore = require './account-store'
WorkspaceStore = require './workspace-store'
MailboxPerspective = require '../../mailbox-perspective'
CategoryStore = require './category-store'
Actions = require '../actions'

class FocusedPerspectiveStore extends NylasStore
  constructor: ->
    @_current = MailboxPerspective.forNothing()

    @listenTo CategoryStore, @_onCategoryStoreChanged
    @listenTo Actions.focusMailboxPerspective, @_onFocusPerspective
    @listenTo Actions.focusDefaultMailboxPerspectiveForAccounts, @_onFocusPerspectiveForAccounts
    @_listenToCommands()

  _listenToCommands: =>
    NylasEnv.commands.add(document.body, {
      'navigation:go-to-inbox'   : =>
        @_setPerspectiveByName("inbox")
      'navigation:go-to-sent'    : =>
        @_setPerspectiveByName("sent")
      'navigation:go-to-starred' : =>
        @_setPerspective(MailboxPerspective.forStarred(@_current.accountIds))
      'navigation:go-to-drafts'  : =>
        @_setPerspective(MailboxPerspective.forDrafts(@_current.accountIds))
      'navigation:go-to-all'     : =>
        categories = @_current.accountIds.map (aid) -> CategoryStore.getArchiveCategory(aid)
        @_setPerspective(MailboxPerspective.forCategories(categories))
      'navigation:go-to-contacts': => ## TODO
      'navigation:go-to-tasks'   : => ## TODO
      'navigation:go-to-label'   : => ## TODO
    })

  _isValidPerspective: (perspective) =>
    # Ensure all the accountIds referenced in the perspective still exist
    return false unless @_isValidAccountSet(perspective.accountIds)
    # Ensure all the categories referenced in the perspective still exist
    return false unless perspective.categories().every((c) =>
      return !!CategoryStore.byId(c.accountId, c.id))
    return true

  _isValidAccountSet: (ids) =>
    accountIds = AccountStore.accountIds()
    return ids.every((a) => accountIds.includes(a))

  _initializeFromSavedState: =>
    json = NylasEnv.savedState.perspective
    sidebarAccountIds = NylasEnv.savedState.sidebarAccountIds

    if json
      perspective = MailboxPerspective.fromJSON(json)

    if not perspective or not @_isValidPerspective(perspective)
      perspective = @_defaultPerspective()
      sidebarAccountIds = perspective.accountIds

    if not sidebarAccountIds or not @_isValidAccountSet(sidebarAccountIds) or sidebarAccountIds.length < perspective.accountIds.length
      sidebarAccountIds = perspective.accountIds

    @_setPerspective(perspective, sidebarAccountIds)

  # Inbound Events
  _onCategoryStoreChanged: ->
    if @_current.isEqual(MailboxPerspective.forNothing())
      @_initializeFromSavedState()
    else if !@_isValidPerspective(@_current)
      @_setPerspective(@_defaultPerspective(@_current.accountIds))

  _onFocusPerspective: (perspective) =>
    # If looking at unified inbox, don't attempt to change the sidebar accounts
    sidebarIsUnifiedInbox = @sidebarAccountIds().length > 1
    if sidebarIsUnifiedInbox
      @_setPerspective(perspective)
    else
      @_setPerspective(perspective, perspective.accountIds)

  # Takes an optional array of `sidebarAccountIds`. By default, this method will
  # set the sidebarAccountIds to the perspective's accounts if no value is
  # provided
  _onFocusPerspectiveForAccounts: (accountsOrIds, {sidebarAccountIds} = {}) =>
    return unless accountsOrIds
    perspective = @_defaultPerspective(accountsOrIds)
    @_setPerspective(perspective, sidebarAccountIds || perspective.accountIds)

  _defaultPerspective: (accountsOrIds = AccountStore.accountIds()) ->
    perspective = MailboxPerspective.forInbox(accountsOrIds)

    # If no account ids were selected, or the categories for these accounts have
    # not loaded yet, return forNothing(). This means that the next time the
    # CategoryStore triggers, we'll try again.
    if perspective.categories().length is 0
      return MailboxPerspective.forNothing()
    return perspective

  _setPerspective: (perspective, sidebarAccountIds) ->
    shouldTrigger = false

    if !perspective.isEqual(@_current)
      NylasEnv.savedState.perspective = perspective.toJSON()
      @_current = perspective
      shouldTrigger = true

    if sidebarAccountIds and !_.isEqual(NylasEnv.savedState.sidebarAccountIds, sidebarAccountIds)
      NylasEnv.savedState.sidebarAccountIds = sidebarAccountIds
      shouldTrigger = true

    @trigger() if shouldTrigger

    if perspective.drafts
      desired = WorkspaceStore.Sheet.Drafts
    else
      desired = WorkspaceStore.Sheet.Threads

    # Always switch to the correct sheet and pop to root when perspective set
    if desired and WorkspaceStore.rootSheet() isnt desired
      Actions.selectRootSheet(desired)
    Actions.popToRootSheet()

  _setPerspectiveByName: (categoryName) ->
    categories = @_current.accountIds.map (aid) ->
      CategoryStore.getStandardCategory(aid, categoryName)
    categories = _.compact(categories)
    return if categories.length is 0
    @_setPerspective(MailboxPerspective.forCategories(categories))

  # Public Methods

  current: =>
    @_current

  sidebarAccountIds: =>
    ids = NylasEnv.savedState.sidebarAccountIds
    if !ids or !ids.length or !ids.every((id) => AccountStore.accountForId(id))
      ids = NylasEnv.savedState.sidebarAccountIds = AccountStore.accountIds()

    # Always defer to the AccountStore for the desired order of accounts in
    # the sidebar - users can re-arrange them!
    order = AccountStore.accountIds()
    ids = ids.sort((a, b) => order.indexOf(a) - order.indexOf(b))

    return ids

module.exports = new FocusedPerspectiveStore()
