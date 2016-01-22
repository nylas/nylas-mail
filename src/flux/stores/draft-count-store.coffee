Reflux = require 'reflux'
_ = require 'underscore'
AccountStore = require './account-store'
DatabaseStore = require './database-store'
DraftStore = require './draft-store'
Actions = require '../actions'
Message = require '../models/message'

###
Public: The DraftCountStore exposes a simple API for getting the number of
drafts in the user's account. If you plugin needs the number of drafts,
it's more efficient to observe the DraftCountStore than retrieve the value
yourself from the database.

The DraftCountStore is only available in the main window.
###

if not NylasEnv.isMainWindow() and not NylasEnv.inSpecMode() then return

DraftCountStore = Reflux.createStore
  init: ->
    @listenTo AccountStore, @_onAccountChanged
    @listenTo DraftStore, @_onDraftChanged
    @_count = null
    _.defer => @_fetchCount()

  # Public: Returns the number of drafts in the user's mailbox
  count: ->
    @_count

  _onAccountChanged: ->
    @_onDraftChanged()

  _onDraftChanged: ->
    @_fetchCountDebounced ?= _.debounce(@_fetchCount, 250)
    @_fetchCountDebounced()

  _fetchCount: ->
    account = AccountStore.current()
    return unless account

    DatabaseStore.count(Message, [
      Message.attributes.draft.equal(true)
      Message.attributes.accountId.equal(account.id)
    ]).then (count) =>
      return if @_count is count
      @_count = count
      @trigger()

module.exports = DraftCountStore
