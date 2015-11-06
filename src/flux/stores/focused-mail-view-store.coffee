NylasStore = require 'nylas-store'
WorkspaceStore = require './workspace-store'
MailViewFilter = require '../../mail-view-filter'
CategoryStore = require './category-store'
AccountStore = require './account-store'
Actions = require '../actions'

class FocusedMailViewStore extends NylasStore
  constructor: ->
    @listenTo CategoryStore, @_onCategoryStoreChanged
    @listenTo Actions.focusMailView, @_onFocusMailView
    @listenTo Actions.searchQueryCommitted, @_onSearchQueryCommitted
    @_onCategoryStoreChanged()

  # Inbound Events
  _onCategoryStoreChanged: ->
    if not @_mailView
      @_setMailView(@_defaultMailView())
    else if not CategoryStore.byId(@_mailView.categoryId())
      @_setMailView(@_defaultMailView())

  _onFocusMailView: (filter) =>
    return if filter.isEqual(@_mailView)
    Actions.selectRootSheet(WorkspaceStore.Sheet.Threads)
    Actions.searchQueryCommitted('')
    @_setMailView(filter)

  _onSearchQueryCommitted: (query="") ->
    if typeof(query) != "string"
      query = query[0].all

    if query.trim().length > 0
      @_mailViewBeforeSearch ?= @_mailView
      @_setMailView(MailViewFilter.forSearch(query))
    else if query.trim().length is 0
      @_mailViewBeforeSearch ?= @_defaultMailView()
      @_setMailView(@_mailViewBeforeSearch)
      @_mailViewBeforeSearch = null

  _defaultMailView: ->
    category = CategoryStore.getStandardCategory("inbox")
    return null unless category
    MailViewFilter.forCategory(category)

  _setMailView: (filter) ->
    return if filter?.isEqual(@_mailView)
    @_mailView = filter
    @trigger()

  # Public Methods

  mailView: -> @_mailView ? null

module.exports = new FocusedMailViewStore()
