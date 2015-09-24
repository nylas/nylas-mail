_ = require 'underscore'
AccountStore = require './account-store'
DatabaseStore = require './database-store'
NylasStore = require 'nylas-store'

class NylasSyncStatusStore extends NylasStore

  constructor: ->
    @_statesByAccount = {}

    @listenTo AccountStore, @_onAccountsChanged
    @listenTo DatabaseStore, @_onChange
    @_onAccountsChanged()

  _onAccountsChanged: =>
    promises = []
    AccountStore.items().forEach (item) =>
      return if @_statesByAccount[item.id]
      promises.push DatabaseStore.findJSONObject("NylasSyncWorker:#{item.id}").then (json) =>
        @_statesByAccount[item.id] = json ? {}
    Promise.all(promises).then =>
      @trigger()

  _onChange: (change) =>
    if change.objectClass is 'JSONObject' and change.objects[0].key.indexOf('NylasSyncWorker') is 0
      [worker, accountId] = change.objects[0].key.split(':')
      @_statesByAccount[accountId] = change.objects[0].json
      @trigger()

  state: =>
    @_statesByAccount

  isComplete: ->
    for acctId, state of @_statesByAccount
      for model, modelState of state
        return false if not modelState.complete
    return true

  busy: =>
    for accountId, states of @_statesByAccount
      for key, state of states
        if state.busy
          return true
      false

module.exports = new NylasSyncStatusStore()
