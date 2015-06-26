Reflux = require 'reflux'
_ = require 'underscore'
NamespaceStore = require './namespace-store'
DatabaseStore = require './database-store'
DraftStore = require './draft-store'
Actions = require '../actions'
Message = require '../models/message'

###
Public: The DraftCountStore exposes a simple API for getting the number of
drafts in the user's account. If you plugin needs the number of drafts,
it's more efficient to observe the DraftCountStore than retrieve the value
yourself from the database.
###
DraftCountStore = Reflux.createStore
  init: ->
    @listenTo NamespaceStore, @_onNamespaceChanged
    @listenTo DraftStore, @_onDraftChanged
    @_count = null
    _.defer => @_fetchCount()

  # Public: Returns the number of drafts in the user's mailbox
  count: ->
    @_count

  _onNamespaceChanged: ->
    @_onDraftChanged()

  _onDraftChanged: ->
    @_fetchCountDebounced ?= _.debounce(@_fetchCount, 250)
    @_fetchCountDebounced()

  _fetchCount: ->
    namespace = NamespaceStore.current()
    return unless namespace

    DatabaseStore.count(Message, [
      Message.attributes.draft.equal(true)
    ]).then (count) =>
      return if @_count is count
      @_count = count
      @trigger()

module.exports = DraftCountStore
