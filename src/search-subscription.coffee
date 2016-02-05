_ = require 'underscore'
Rx = require 'rx-lite'

NylasAPI = require './flux/nylas-api'
DatabaseStore = require './flux/stores/database-store'
Thread = require './flux/models/thread'
MutableQuerySubscription = require './flux/models/mutable-query-subscription'

class SearchSubscription extends MutableQuerySubscription

  constructor: (@_terms, @_accountIds) ->
    super(null, {asResultSet: true})

    @_termsVersion = 0
    _.defer => @retrievePage(0)

  terms: =>
    @_terms

  setTerms: (terms) =>
    @_terms = terms
    @_termsVersion += 1
    @retrievePage(0)

  replaceRange: (range) =>
    # TODO

  # Accessing Data

  retrievePage: (idx) =>
    termsVersion = @_termsVersion += 1
    resultCount = 0
    resultIds = []

    resultReturned = =>
      # Don't emit a "result" until we have at least one thread to display.
      # Otherwise it will show "No Results Found"
      if resultIds.length > 0 or resultCount is @_accountIds.length
        query = DatabaseStore.findAll(Thread).where(id: resultIds).order(Thread.attributes.lastMessageReceivedTimestamp.descending())
        @replaceQuery(query)

    @_accountIds.forEach (aid) =>
      NylasAPI.makeRequest
        method: 'GET'
        path: "/threads/search?q=#{encodeURIComponent(@_terms)}"
        accountId: aid
        json: true
        returnsModel: true

      .then (threads) =>
        return unless @_termsVersion is termsVersion
        resultCount += 1
        resultIds = resultIds.concat _.pluck(threads, 'id')
        resultReturned()

      .catch (err) =>
        resultCount += 1
        resultReturned()

module.exports = SearchSubscription
