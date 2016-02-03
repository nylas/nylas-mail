Rx = require 'rx-lite'
NylasStore = require 'nylas-store'
DatabaseStore = require './database-store'
AccountStore = require './account-store'

class ContactRankingStore extends NylasStore

  constructor: ->
    @_values = {}
    @_valuesAllAccounts = null
    @_disposables = []
    @listenTo AccountStore, @_onAccountsChanged
    @_registerObservables(AccountStore.accounts())

  _registerObservables: (accounts) =>
    @_disposables.forEach (disp) -> disp.dispose()
    @_disposables = accounts.map ({accountId}) =>
      query = DatabaseStore.findJSONBlob("ContactRankingsFor#{accountId}")
      return Rx.Observable.fromQuery(query)
        .subscribe @_onRankingsChanged.bind(@, accountId)

  _onRankingsChanged: (accountId, json) =>
    @_values[accountId] = if json then json.value else null
    @_valuesAllAccounts = null
    @trigger()

  _onAccountsChanged: =>
    @_registerObservables(AccountStore.accounts())

  valueFor: (accountId) =>
    @_values[accountId]

  valuesForAllAccounts: =>
    unless @_valuesAllAccounts
      combined = {}
      for acctId, values of @_values
        for email, score of values
          if combined[email]
            combined[email] = Math.max(combined[email], score)
          else
            combined[email] = score
      @_valuesAllAccounts = combined

    return @_valuesAllAccounts

  reset: =>
    @_valuesAllAccounts = null
    @_values = {}

module.exports = new ContactRankingStore()
