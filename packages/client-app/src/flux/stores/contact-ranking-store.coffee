Rx = require 'rx-lite'
NylasStore = require 'nylas-store'
DatabaseStore = require('./database-store').default
AccountStore = require('./account-store').default

class ContactRankingStore extends NylasStore

  constructor: ->
    @_values = {}
    @_valuesAllAccounts = null
    @_disposables = {}
    @listenTo AccountStore, @_onAccountsChanged
    @_registerObservables(AccountStore.accounts())

  _registerObservables: (accounts) =>
    nextDisposables = {}

    # Create new observables, reusing existing ones when possible
    # (so they don't trigger with initial state unnecesarily)
    for acct in accounts
      if @_disposables[acct.id]
        nextDisposables[acct.id] = @_disposables[acct.id]
        delete @_disposables[acct.id]
      else
        query = DatabaseStore.findJSONBlob("ContactRankingsFor#{acct.id}")
        callback = @_onRankingsChanged.bind(@, acct.id)
        nextDisposables[acct.id] = Rx.Observable.fromQuery(query).subscribe(callback)

    # Remove unused observables in the old set
    for key, disposable of @_disposables
      disposable.dispose()

    @_disposables = nextDisposables

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
