Rx = require 'rx-lite'
NylasStore = require 'nylas-store'
DatabaseStore = require './database-store'
AccountStore = require './account-store'

class ContactRankingStore extends NylasStore

  constructor: ->
    @_values = {}
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
    @_values[accountId] = if json? then json.value else null
    @trigger()

  _onAccountsChanged: =>
    @_registerObservables(AccountStore.accounts())

  valueFor: (accountId) ->
    @_values[accountId]

  reset: ->
    @_values = {}

module.exports = new ContactRankingStore()
