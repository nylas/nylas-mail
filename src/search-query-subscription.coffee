_ = require 'underscore'
Rx = require 'rx-lite'
NylasAPI = require './flux/nylas-api'
AccountStore = require './flux/stores/account-store'
DatabaseStore = require './flux/stores/database-store'
Thread = require './flux/models/thread'
Actions = require './flux/actions'
MutableQuerySubscription = require './flux/models/mutable-query-subscription'


class SearchQuerySubscription extends MutableQuerySubscription

  constructor: (@_searchQuery, @_accountIds) ->
    super(null, {asResultSet: true})
    @_searchQueryVersion = 0
    @_connections = []
    _.defer => @performSearch()

  searchQuery: =>
    @_searchQuery

  setSearchQuery: (searchQuery) =>
    @_searchQuery = searchQuery
    @_searchQueryVersion += 1
    @performSearch()

  replaceRange: (range) =>
    # TODO

  performSearch: =>
    @performLocalSearch()
    @performRemoteSearch()

  performLocalSearch: =>
    dbQuery = DatabaseStore.findAll(Thread)
    if @_accountIds.length is 1
      dbQuery = dbQuery.where(accountId: @_accountIds[0])
    dbQuery = dbQuery.search(@_searchQuery).limit(20)
    dbQuery.then((results) =>
      if results.length > 0
        @replaceQuery(dbQuery)
    )

  performRemoteSearch: (idx) =>
    searchQueryVersion = @_searchQueryVersion += 1
    accountsSearched = new Set()
    resultIds = []

    resultsReturned = =>
      # Don't emit a "result" until we have at least one thread to display.
      # Otherwise it will show "No Results Found"
      if resultIds.length > 0 or accountsSearched.size is @_accountIds.length
        if @_set?.ids().length > 0
          currentResultIds = @_set.ids()
          resultIds = _.uniq(currentResultIds.concat(resultIds))
        dbQuery = DatabaseStore.findAll(Thread).where(id: resultIds).order(Thread.attributes.lastMessageReceivedTimestamp.descending())
        @replaceQuery(dbQuery)

    @_connections = @_accountIds.map (accId) =>
      NylasAPI.startLongConnection
        accountId: accId
        path: "/threads/search/streaming?q=#{encodeURIComponent(@_searchQuery)}"
        onResults: (results) =>
          threads = results[0]
          return unless @_searchQueryVersion is searchQueryVersion
          resultIds = resultIds.concat _.pluck(threads, 'id')
          resultsReturned()
        onStatusChanged: (conn) =>
          if conn.isClosed()
            accountsSearched.add(accId)
            resultsReturned()


  closeConnections: =>
    @_connections.forEach((conn) => conn.end())

  removeCallback: =>
    super()
    @closeConnections() if @callbackCount() is 0

module.exports = SearchQuerySubscription
