_ = require 'underscore'
Rx = require 'rx-lite'

NylasAPI = require './flux/nylas-api'
DatabaseStore = require './flux/stores/database-store'
Thread = require './flux/models/thread'
MutableQuerySubscription = require './flux/models/mutable-query-subscription'

class SearchSubscription extends MutableQuerySubscription

  constructor: (@_terms, @_accountIds) ->
    super(null, {asResultSet: true})

    @_version = 0
    _.defer => @retrievePage(0)

  terms: =>
    @_terms

  setTerms: (terms) =>
    @_terms = terms
    @_version += 1
    @retrievePage(0)

  replaceRange: (range) =>
    @retrievePage(Math.floor(range.start / 100))

  # Accessing Data

  retrievePage: (idx) =>
    version = @_version += 1

    requests = @_accountIds.map (aid) =>
      NylasAPI.makeRequest
        method: 'GET'
        path: "/threads/search?q=#{encodeURIComponent(@_terms)}"
        accountId: aid
        json: true
        returnsModel: true

    Promise.all(requests).then (resultArrays) =>
      return unless @_version is version
      resultIds = []
      for resultArray in resultArrays
        resultIds = resultIds.concat _.pluck(resultArray, 'id')

      query = DatabaseStore.findAll(Thread).where(id: resultIds).order(Thread.attributes.lastMessageReceivedTimestamp.descending())
      @replaceQuery(query)

module.exports = SearchSubscription
