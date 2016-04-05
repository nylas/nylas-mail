_ = require 'underscore'
Rx = require 'rx-lite'
AccountStore = require './account-store'
DatabaseStore = require './database-store'
NylasStore = require 'nylas-store'

ModelsForSync = [
  'threads',
  'messages',
  'labels',
  'folders',
  'drafts',
  'contacts',
  'calendars',
  'events'
]

class NylasSyncStatusStore extends NylasStore
  ModelsForSync: ModelsForSync

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
    return false if _.isEmpty(@_statesByAccount[acctId])
    if model
      return @_statesByAccount[acctId][model]?.complete ? false

    for _model, modelState of @_statesByAccount
      continue unless _model in ModelsForSync
      return false if not modelState.complete
    return true

  isSyncComplete: =>
    return false if _.isEmpty(@_statesByAccount)
    for acctId of @_statesByAccount
      return false if not @isSyncCompleteForAccount(acctId)
    return true

  whenSyncComplete: =>
    return Promise.resolve() if @isSyncComplete()
    return new Promise (resolve) =>
      unsubscribe = @listen =>
        if @isSyncComplete()
          unsubscribe()
          resolve()

  busy: =>
    for accountId, states of @_statesByAccount
      for key, state of states
        if state.busy
          return true
      false

  connected: =>
    # Return true if any account is in a state other than `retrying`.
    # When data isn't received, NylasLongConnection closes the socket and
    # goes into `retrying` state.
    statuses = _.values(@_statesByAccount).map (state) ->
      state.longConnectionStatus

    if statuses.length is 0
      return true

    return _.any statuses, (status) -> status isnt 'closed'

  nextRetryTimestamp: =>
    retryDates = _.values(@_statesByAccount).map (state) ->
      state.nextRetryTimestamp
    _.compact(retryDates).sort((a, b) => a < b).pop()

module.exports = new NylasSyncStatusStore()
