Reflux = require 'reflux'
{Actions,
 Contact,
 Thread,
 DatabaseStore,
 AccountStore,
 ContactStore} = require 'nylas-exports'
_ = require 'underscore'

# Stores should closely match the needs of a particular part of the front end.
# For example, we might create a "MessageStore" that observes this store
# for changes in selectedThread, "DatabaseStore" for changes to the underlying database,
# and vends up the array used for that view.

SearchSuggestionStore = Reflux.createStore
  init: ->
    @_query = ""
    @_committedQuery = ""
    @_clearResults()

    @listenTo Actions.searchQueryChanged, @onSearchQueryChanged
    @listenTo Actions.searchQueryCommitted, @onSearchQueryCommitted
    @listenTo Actions.searchBlurred, @onSearchBlurred

  onSearchQueryChanged: (query, account) ->
    @_query = query
    @_account = account
    @trigger()
    _.defer => @_rebuildResults()

  onSearchQueryCommitted: (query, account) ->
    @_query = query
    @_account = accountId
    @_committedQuery = query
    @_clearResults()

  onSearchBlurred: ->
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

  queryKeyAndVal: ->
    return {} unless @_query and @_query.length > 0
    term = @_query[0]
    key = Object.keys(term)[0]
    val = term[key]
    {key, val}

  committedQuery: -> @_committedQuery

  suggestions: ->
    @_suggestions

module.exports = SearchSuggestionStore
