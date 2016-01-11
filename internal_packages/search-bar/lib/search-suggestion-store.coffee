Reflux = require 'reflux'
{Contact,
 Thread,
 Actions,
 DatabaseStore,
 AccountStore,
 FocusedPerspectiveStore,
 ContactStore} = require 'nylas-exports'
_ = require 'underscore'

SearchActions = require './search-actions'

# Stores should closely match the needs of a particular part of the front end.
# For example, we might create a "MessageStore" that observes this store
# for changes in selectedThread, "DatabaseStore" for changes to the underlying database,
# and vends up the array used for that view.

SearchSuggestionStore = Reflux.createStore
  init: ->
    @_query = ""
    @_clearResults()

    @listenTo FocusedPerspectiveStore, @_onPerspectiveChanged
    @listenTo SearchActions.querySubmitted, @_onQuerySubmitted
    @listenTo SearchActions.queryChanged, @_onQueryChanged
    @listenTo SearchActions.searchBlurred, @_onSearchBlurred

  _onPerspectiveChanged: =>
    @_query = FocusedPerspectiveStore.current()?.searchQuery ? ""
    @trigger()

  _onQueryChanged: (query) ->
    @_query = query
    @trigger()
    _.defer => @_rebuildResults()

  _onQuerySubmitted: (query) ->
    @_query = query
    perspective = FocusedPerspectiveStore.current()
    account = perspective.account

    if @_query.trim().length > 0
      @_perspectiveBeforeSearch ?= perspective
      Actions.focusMailboxPerspective(MailboxPerspective.forSearch(account, @_query))

    else if @_query.trim().length is 0
      if @_perspectiveBeforeSearch
        Actions.focusMailboxPerspective(@_perspectiveBeforeSearch)
        @_perspectiveBeforeSearch = null
      else
        Actions.focusDefaultMailboxPerspectiveForAccount(account)

    @_clearResults()

  _onSearchBlurred: ->
    @_clearResults()

  _clearResults: ->
    @_threadResults = null
    @_contactResults = null
    @_suggestions = []
    @trigger()

  _rebuildResults: ->
    {key, val} = @queryKeyAndVal()
    return @_clearResults() unless key and val

    ContactStore.searchContacts(val, accountId: @_account.id, limit:10).then (results) =>
      @_contactResults = results
      @_rebuildThreadResults()
      @_compileSuggestions()

  _rebuildThreadResults: ->
    {key, val} = @queryKeyAndVal()
    return @_threadResults = [] unless val

    # Don't update thread results if a previous query is still running, it'll
    # just make performance even worse. When the old result comes in, re-run
    return if @_threadQueryInFlight

    @_threadQueryInFlight = true
    DatabaseStore.findAll(Thread)
    .where(Thread.attributes.subject.like(val))
    # TODO This account check should be removed with the unified search refactor
    .where(Thread.attributes.accountId.equal(@_account.id))
    .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
    .limit(4)
    .then (results) =>
      @_threadQueryInFlight = false
      if val is @queryKeyAndVal().val
        @_threadResults = results
        @_compileSuggestions()
      else
        @_rebuildThreadResults()

  _compileSuggestions: ->
    {key, val} = @queryKeyAndVal()
    return unless key and val

    @_suggestions = []
    @_suggestions.push
      label: "Message Contains: #{val}"
      value: [{"all": val}]

    if @_threadResults?.length
      @_suggestions.push
        divider: 'Threads'
      _.each @_threadResults, (thread) =>
        @_suggestions.push({thread: thread})

    if @_contactResults?.length
      @_suggestions.push
        divider: 'People'
      _.each @_contactResults, (contact) =>
        @_suggestions.push
          contact: contact
          value: [{"all": contact.email}]

    @trigger()

  # Exposed Data

  query: -> @_query

  suggestions: -> @_suggestions

module.exports = SearchSuggestionStore
