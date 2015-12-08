Rx = require 'rx-lite'
NylasStore = require 'nylas-store'
DatabaseStore = require './database-store'
AccountStore = require './account-store'

class ContactRankingStore extends NylasStore

  constructor: ->
    @_value = null
    @_accountId = null

    {Accounts} = require 'nylas-observables'
    Accounts.forCurrentId().flatMapLatest (accountId) =>
      query = DatabaseStore.findJSONBlob("ContactRankingsFor#{accountId}")
      return Rx.Observable.fromQuery(query)
    .subscribe (json) =>
      @_value = if json? then json.value else null
      @trigger()

  value: ->
    @_value

  reset: ->
    @_value = null

module.exports = new ContactRankingStore()
