NylasStore = require 'nylas-store'
WorkspaceStore = require './workspace-store'
AccountStore = require './workspace-store'
MailboxPerspective = require '../../mailbox-perspective'
CategoryStore = require './category-store'
Actions = require '../actions'

class FocusedPerspectiveStore extends NylasStore
  constructor: ->
    @listenTo CategoryStore, @_onCategoryStoreChanged
    @listenTo Actions.focusMailboxPerspective, @_onFocusMailView
    @listenTo Actions.searchQueryCommitted, @_onSearchQueryCommitted
    @_onCategoryStoreChanged()

  # Inbound Events
  _onCategoryStoreChanged: ->
    if not @_current
      @_setPerspective(@_defaultPerspective())
    else
      account = @_current.account
      catId   = @_current.categoryId()
      if catId and not CategoryStore.byId(account, catId)
        @_setPerspective(@_defaultPerspective())

  _onFocusMailView: (filter) =>
    return if filter.isEqual(@_current)
    if WorkspaceStore.Sheet.Threads
      Actions.selectRootSheet(WorkspaceStore.Sheet.Threads)
    Actions.searchQueryCommitted('')
    @_setPerspective(filter)

  _onSearchQueryCommitted: (query="", account) ->
    if typeof(query) != "string"
      query = query[0].all

    if query.trim().length > 0
      @_currentBeforeSearch ?= @_current
      @_setPerspective(MailboxPerspective.forSearch(account, query))
    else if query.trim().length is 0
      @_currentBeforeSearch ?= @_defaultPerspective()
      @_setPerspective(@_currentBeforeSearch)
      @_currentBeforeSearch = null

  _defaultPerspective: ->
    # TODO Update unified MailboxPerspective
    account = AccountStore.accounts()[0]
    category = CategoryStore.getStandardCategory(account, "inbox")
    return null unless category
    MailViewFilter.forCategory(account, category)
    # MailboxPerspective.unified()

  _setPerspective: (filter) ->
    return if filter?.isEqual(@_current)
    @_current = filter
    @trigger()

  # Public Methods

  current: -> @_current ? null

module.exports = new FocusedPerspectiveStore()
