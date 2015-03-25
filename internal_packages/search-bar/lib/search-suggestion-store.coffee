Reflux = require 'reflux'
{DatabaseStore, Actions, Contact} = require 'inbox-exports'
_ = require 'underscore-plus'

# Stores should closely match the needs of a particular part of the front end.
# For example, we might create a "MessageStore" that observes this store
# for changes in selectedThread, "DatabaseStore" for changes to the underlying database,
# and vends up the array used for that view.

SearchSuggestionStore = Reflux.createStore
  init: ->
    @_all = []
    @_suggestions = []
    @_searchConstants = {"from": 4, "subject": 2}
    @_query = ""
    @_committedQuery = ""

    @listenTo Actions.searchConstantsChanged, @onSearchConstantsChanged
    @listenTo Actions.searchQueryChanged, @onSearchQueryChanged
    @listenTo Actions.searchQueryCommitted, @onSearchQueryCommitted
    @listenTo Actions.searchBlurred, @onSearchBlurred
    @listenTo DatabaseStore, @onDataChanged
    @onDataChanged()

  onDataChanged: (change) ->
    return if change && change.objectClass != Contact.name
    DatabaseStore.findAll(Contact).then (contacts) =>
      @_all = contacts
      @repopulate()

  onSearchQueryChanged: (query) ->
    @_query = query
    @repopulate()

  onSearchConstantsChanged: (constants) ->
    @_searchConstants = constants
    @trigger()
    Actions.searchQueryCommitted(@_query)

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
    val = term[key]?.toLowerCase()
    return @trigger(@) unless val

    contactResults = []
    for contact in @_all
      if contact.name?.toLowerCase().indexOf(val) == 0 or contact.email?.toLowerCase().indexOf(val) == 0
        contactResults.push(contact)
      if contactResults.length is 10
        break

    @_suggestions.push
      label: "Message Contains: #{val}"
      value: [{"all": val}]

    if contactResults.length
      @_suggestions.push
        divider: 'People'

      _.each contactResults, (contact) =>
        if contact.name
          label = "#{contact.name} <#{contact.email}>"
        else
          label = contact.email

        @_suggestions.push
          label: label
          value: [{"participants": contact.email}]

    @trigger(@)

  # Exposed Data

  query: -> @_query

  committedQuery: -> @_committedQuery

  suggestions: ->
    @_suggestions

  searchConstants: ->
    @_searchConstants

module.exports = SearchSuggestionStore
