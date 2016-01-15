_ = require 'underscore'
Rx = require 'rx-lite'

NylasAPI = require './flux/nylas-api'
DatabaseStore = require './flux/stores/database-store'
Thread = require './flux/models/thread'
MutableQuerySubscription = require './flux/models/mutable-query-subscription'

class SearchSubscription extends MutableQuerySubscription

  constructor: (@_terms, @_accountId) ->
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

    NylasAPI.makeRequest
      method: 'GET'
      path: "/threads/search?q=#{encodeURIComponent(@_terms)}"
      accountId: @_accountId
      json: true
      returnsModel: true
    .then (threads) =>
      return unless @_version is version
      query = DatabaseStore.findAll(Thread).where(id: _.pluck(threads, 'id'))
      @replaceQuery(query)

module.exports = SearchSubscription
