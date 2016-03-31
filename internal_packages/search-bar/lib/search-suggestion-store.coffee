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
    @_searchQuery = FocusedPerspectiveStore.current().searchQuery ? ""
    @_searchSuggestionsVersion = 1
    @_clearResults()

    @listenTo FocusedPerspectiveStore, @_onPerspectiveChanged
    @listenTo SearchActions.querySubmitted, @_onQuerySubmitted
    @listenTo SearchActions.queryChanged, @_onQueryChanged
    @listenTo SearchActions.searchBlurred, @_onSearchBlurred

  _onPerspectiveChanged: =>
    @_searchQuery = FocusedPerspectiveStore.current().searchQuery ? ""
    @trigger()

  _onQueryChanged: (query) =>
    @_searchQuery = query
    @_compileResults()
    _.defer => @_rebuildResults()

  _onQuerySubmitted: (query) =>
    @_searchQuery = query
    current = FocusedPerspectiveStore.current()

    if @queryPopulated()
      Actions.recordUserEvent("Commit Search Query", {})
      @_perspectiveBeforeSearch ?= current
      next = MailboxPerspective.forSearch(current.accountIds, @_searchQuery.trim())
      Actions.focusMailboxPerspective(next)

    else if current.isSearch()
      if @_perspectiveBeforeSearch
        Actions.focusMailboxPerspective(@_perspectiveBeforeSearch)
        @_perspectiveBeforeSearch = null
      else
        Actions.focusDefaultMailboxPerspectiveForAccounts(AccountStore.accounts())

    @_clearResults()

  _onSearchBlurred: =>
    @_clearResults()

  _clearResults: =>
    @_searchSuggestionsVersion = 1
    @_threadResults = []
    @_contactResults = []
    @_suggestions = []
    @trigger()

  _rebuildResults: =>
    return @_clearResults() unless @queryPopulated()
    @_searchSuggestionsVersion += 1
    @_fetchThreadResults()
    @_fetchContactResults()

  _fetchContactResults: =>
    version = @_searchSuggestionsVersion
    ContactStore.searchContacts(@_searchQuery, limit:10).then (contacts) =>
      return unless version is @_searchSuggestionsVersion
      @_contactResults = contacts
      @_compileResults()

  _fetchThreadResults: =>
    return if @_fetchingThreadResultsVersion
    @_fetchingThreadResultsVersion = @_searchSuggestionsVersion

    databaseQuery = DatabaseStore.findAll(Thread)
      .where(Thread.attributes.subject.like(@_searchQuery))
      .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
      .limit(4)

    accountIds = FocusedPerspectiveStore.current().accountIds
    if accountIds instanceof Array
      databaseQuery.where(Thread.attributes.accountId.in(accountIds))

    databaseQuery.then (results) =>
      # We've fetched the latest thread results - display them!
      if @_searchSuggestionsVersion is @_fetchingThreadResultsVersion
        @_fetchingThreadResultsVersion = null
        @_threadResults = results
        @_compileResults()
      # We're behind and need to re-run the search for the latest results
      else if @_searchSuggestionsVersion > @_fetchingThreadResultsVersion
        @_fetchingThreadResultsVersion = null
        @_fetchThreadResults()
      else
        @_fetchingThreadResultsVersion = null

  _compileResults: =>
    @_suggestions = []

    @_suggestions.push
      label: "Message Contains: #{@_searchQuery}"
      value: @_searchQuery

    if @_threadResults.length
      @_suggestions.push
        divider: 'Threads'
      @_suggestions.push({thread}) for thread in @_threadResults

    if @_contactResults.length
      @_suggestions.push
        divider: 'People'
      for contact in @_contactResults
        @_suggestions.push
          contact: contact
          value: contact.email

    @trigger()

  # Exposed Data

  query: => @_searchQuery

  queryPopulated: => @_searchQuery and @_searchQuery.trim().length > 0

  suggestions: => @_suggestions

module.exports = new SearchSuggestionStore()
