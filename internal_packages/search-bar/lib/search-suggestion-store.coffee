_ = require 'underscore'
NylasStore = require 'nylas-store'
{Contact,
 Thread,
 Actions,
 DatabaseStore,
 AccountStore,
 FocusedPerspectiveStore,
 MailboxPerspective,
 ContactStore} = require 'nylas-exports'

SearchActions = require './search-actions'

# Stores should closely match the needs of a particular part of the front end.
# For example, we might create a "MessageStore" that observes this store
# for changes in selectedThread, "DatabaseStore" for changes to the underlying database,
# and vends up the array used for that view.

class SearchSuggestionStore extends NylasStore

  constructor: ->
    @_searchQuery = ""
    @_clearResults()

    @listenTo FocusedPerspectiveStore, @_onPerspectiveChanged
    @listenTo SearchActions.querySubmitted, @_onQuerySubmitted
    @listenTo SearchActions.queryChanged, @_onQueryChanged
    @listenTo SearchActions.searchBlurred, @_onSearchBlurred

  _onPerspectiveChanged: =>
    @_searchQuery = FocusedPerspectiveStore.current()?.searchQuery ? ""
    @trigger()

  _onQueryChanged: (query) =>
    @_searchQuery = query
    @trigger()
    _.defer => @_rebuildResults()

  _onQuerySubmitted: (query) =>
    @_searchQuery = query
    perspective = FocusedPerspectiveStore.current()
    account = perspective.account

    if @_searchQuery.trim().length > 0
      @_perspectiveBeforeSearch ?= perspective
      Actions.focusMailboxPerspective(MailboxPerspective.forSearch(account, @_searchQuery))

    else if @_searchQuery.trim().length is 0
      if @_perspectiveBeforeSearch
        Actions.focusMailboxPerspective(@_perspectiveBeforeSearch)
        @_perspectiveBeforeSearch = null
      else
        Actions.focusDefaultMailboxPerspectiveForAccount(account)

    @_clearResults()

  _onSearchBlurred: =>
    @_clearResults()

  _clearResults: =>
    @_threadResults = null
    @_contactResults = null
    @_suggestions = []
    @trigger()

  _rebuildResults: =>
    return @_clearResults() unless @_searchQuery

    account = FocusedPerspectiveStore.current().account
    ContactStore.searchContacts(@_searchQuery, accountId: account.id, limit:10).then (results) =>
      @_contactResults = results
      @_rebuildThreadResults()
      @_compileSuggestions()

  _rebuildThreadResults: =>
    return @_threadResults = [] unless @_searchQuery

    terms = @_searchQuery
    account = FocusedPerspectiveStore.current().account

    # Don't update thread results if a previous query is still running, it'll
    # just make performance even worse. When the old result comes in, re-run
    return if @_threadQueryInFlight

    databaseQuery = DatabaseStore.findAll(Thread)
      .where(Thread.attributes.subject.like(terms))
      .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
      .limit(4)

    if account
      databaseQuery.where(Thread.attributes.accountId.equal(account.id))

    @_threadQueryInFlight = true
    databaseQuery.then (results) =>
      @_threadQueryInFlight = false
      if terms is @_searchQuery
        @_threadResults = results
        @_compileSuggestions()
      else
        @_rebuildThreadResults()

  _compileSuggestions: =>
    return unless @_searchQuery

    @_suggestions = []
    @_suggestions.push
      label: "Message Contains: #{@_searchQuery}"
      value: @_searchQuery

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
          value: contact.email

    @trigger()

  # Exposed Data

  query: => @_searchQuery

  suggestions: => @_suggestions

module.exports = new SearchSuggestionStore()
