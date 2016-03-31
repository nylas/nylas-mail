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
    resultCount = 0
    resultIds = []

    resultReturned = =>
      # Don't emit a "result" until we have at least one thread to display.
      # Otherwise it will show "No Results Found"
      if resultIds.length > 0 or resultCount is @_accountIds.length
        if @_set?.ids().length > 0
          currentResultIds = @_set.ids()
          resultIds = _.uniq(currentResultIds.concat(resultIds))
        dbQuery = DatabaseStore.findAll(Thread).where(id: resultIds).order(Thread.attributes.lastMessageReceivedTimestamp.descending())
        @replaceQuery(dbQuery)

    @_accountsFailed = []
    @_updateSearchError()

    @_accountIds.forEach (aid) =>
      NylasAPI.makeRequest
        method: 'GET'
        path: "/threads/search?q=#{encodeURIComponent(@_searchQuery)}"
        accountId: aid
        json: true
        timeout: 45000
        returnsModel: true

      .then (threads) =>
        return unless @_searchQueryVersion is searchQueryVersion
        resultCount += 1
        resultIds = resultIds.concat _.pluck(threads, 'id')
        resultReturned()

      .catch (err) =>
        account = AccountStore.accountForId(aid)
        if account
          @_accountsFailed.push("#{account.emailAddress}: #{err.message}")
          @_updateSearchError()
        resultCount += 1
        resultReturned()

  _updateSearchError: =>
    # Do not fire an action to display a notification if no-one is subscribed
    # to our result set anymore.
    return if @callbackCount() is 0

    if @_accountsFailed.length is 0
      Actions.dismissNotificationsMatching({tag: 'search-error'})
    else
      Actions.postNotification
        type: 'error'
        tag: 'search-error'
        sticky: true
        message: "Search failed for one or more accounts (#{@_accountsFailed.join(', ')}). Please try again.",
        icon: 'fa-search-minus'
        actions: [{
            default: true
            dismisses: true
            label: 'Dismiss'
            id: 'search-error:dismiss'
          }]

module.exports = SearchQuerySubscription
