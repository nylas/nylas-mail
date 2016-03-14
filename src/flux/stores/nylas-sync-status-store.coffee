_ = require 'underscore'
Rx = require 'rx-lite'
AccountStore = require './account-store'
DatabaseStore = require './database-store'
NylasStore = require 'nylas-store'

class NylasSyncStatusStore extends NylasStore

  constructor: ->
    @_statesByAccount = {}
    @_subscriptions = {}

    @listenTo AccountStore, @_onAccountsChanged
    @_onAccountsChanged()

  _onAccountsChanged: =>
    AccountStore.accounts().forEach (item) =>
      query = DatabaseStore.findJSONBlob("NylasSyncWorker:#{item.id}")
      @_subscriptions[item.id] ?= Rx.Observable.fromQuery(query).subscribe (json) =>
        state = _.extend({}, json ? {})
        delete state.cursor
        @_statesByAccount[item.id] = state
        @trigger()

  state: =>
    @_statesByAccount

  isSyncCompleteForAccount: (acctId, model) =>
    return false unless @_statesByAccount[acctId]
    if model
      return @_statesByAccount[acctId][model]?.complete ? false
    for _model, modelState of @_statesByAccount[acctId]
      return false if not modelState.complete
    return true

  isSyncComplete: =>
    for acctId of @_statesByAccount
      return false if not @isSyncCompleteForAccount(acctId)
    return true

  busy: =>
    for accountId, states of @_statesByAccount
      for key, state of states
        if state.busy
          return true
      false

module.exports = new NylasSyncStatusStore()
