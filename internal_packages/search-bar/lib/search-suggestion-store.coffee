Reflux = require 'reflux'
{Actions,
 Contact,
 ContactStore} = require 'nylas-exports'
_ = require 'underscore'

# Stores should closely match the needs of a particular part of the front end.
# For example, we might create a "MessageStore" that observes this store
# for changes in selectedThread, "DatabaseStore" for changes to the underlying database,
# and vends up the array used for that view.

SearchSuggestionStore = Reflux.createStore
  init: ->
    @_suggestions = []
    @_query = ""
    @_committedQuery = ""

    @listenTo Actions.searchQueryChanged, @onSearchQueryChanged
    @listenTo Actions.searchQueryCommitted, @onSearchQueryCommitted
    @listenTo Actions.searchBlurred, @onSearchBlurred

  onSearchQueryChanged: (query) ->
    @_query = query
    @repopulate()

  onSearchQueryCommitted: (query) ->
    @_query = query
    @_committedQuery = query
    @_suggestions = []
    @trigger()

  onSearchBlurred: ->
    @_suggestions = []
    @trigger()

  repopulate: ->
    @_suggestions = []
    term = @_query?[0]
    return @trigger(@) unless term

    key = Object.keys(term)[0]
    val = term[key]
    return @trigger(@) unless val

    contactResults = ContactStore.searchContacts(val, limit:10)

    @_suggestions.push
      label: "Message Contains: #{val}"
      value: [{"all": val}]

    if contactResults.length
      @_suggestions.push
        divider: 'People'

      _.each contactResults, (contact) =>
        @_suggestions.push
          contact: contact
          value: [{"participants": contact.email}]

    @trigger(@)

  # Exposed Data

  query: -> @_query

  committedQuery: -> @_committedQuery

  suggestions: ->
    @_suggestions

module.exports = SearchSuggestionStore
