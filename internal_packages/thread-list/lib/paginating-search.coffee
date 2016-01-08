_ = require 'underscore'
Rx = require 'rx-lite'

{NylasAPI,
 Thread,
 MutableQuerySubscription,
 DatabaseStore} = require 'nylas-exports'

class PaginatingSearch

  constructor: (@_terms, @_accountId) ->
    @_version = 0
    @subscription = new MutableQuerySubscription(null, {asResultSet: true})
    _.defer => @retrievePage(0)

  observable: =>
    Rx.Observable.fromPrivateQuerySubscription('search-results', @subscription)

  terms: =>
    @_terms

  setTerms: (terms) =>
    @_terms = terms
    @_version += 1
    @retrievePage(0)

  setRange: (range) =>
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
      @subscription.replaceQuery(query)

module.exports = PaginatingSearch
