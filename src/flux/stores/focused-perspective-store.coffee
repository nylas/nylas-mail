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
    @listenTo Actions.focusDefaultMailboxPerspectiveForAccounts, @_onFocusAccounts
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

  _loadSavedPerspective: (savedPerspective, accounts = AccountStore.accounts()) =>
    if savedPerspective
      perspective = MailboxPerspective.fromJSON(savedPerspective)
      if perspective
        accountIds = _.pluck(accounts, 'id')
        accountIdsNotPresent = _.difference(perspective.accountIds, accountIds)
        perspective = null if accountIdsNotPresent.length > 0

    perspective ?= @_defaultPerspective()
    return perspective

  # Inbound Events

  _onCategoryStoreChanged: ->
    if @_current.isEqual(MailboxPerspective.forNothing())
      perspective = @_loadSavedPerspective(NylasEnv.savedState.perspective)
      @_setPerspective(perspective)
    else
      accountIds = @_current.accountIds
      categories = @_current.categories()
      catExists  = (cat) -> CategoryStore.byId(cat.accountId, cat.id)
      categoryHasBeenDeleted = categories and not _.every(categories, catExists)

      if categoryHasBeenDeleted
        @_setPerspective(@_defaultPerspective(accountIds))

  _onFocusPerspective: (perspective) =>
    @_setPerspective(perspective)

  _onFocusAccounts: (accountsOrIds) =>
    return unless accountsOrIds
    @_setPerspective(MailboxPerspective.forInbox(accountsOrIds))

  _defaultPerspective: (accounts = AccountStore.accounts()) ->
    return MailboxPerspective.forNothing() unless accounts.length > 0
    return MailboxPerspective.forInbox(accounts)

  _setPerspective: (perspective) ->
    unless perspective.isEqual(@_current)
      NylasEnv.savedState.perspective = perspective.toJSON()
      @_current = perspective
      @trigger()

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


module.exports = new FocusedPerspectiveStore()
