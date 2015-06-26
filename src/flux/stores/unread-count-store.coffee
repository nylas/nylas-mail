Reflux = require 'reflux'
_ = require 'underscore'
remote = require 'remote'
app = remote.require 'app'
NamespaceStore = require './namespace-store'
DatabaseStore = require './database-store'
Actions = require '../actions'
Thread = require '../models/thread'

###
Public: The UnreadCountStore exposes a simple API for getting the number of
unread threads in the user's inbox. If you plugin needs the current unread count,
it's more efficient to observe the UnreadCountStore than retrieve the value
yourself from the database.
###
UnreadCountStore = Reflux.createStore
  init: ->
    @listenTo NamespaceStore, @_onNamespaceChanged
    @listenTo DatabaseStore, @_onDataChanged

    @_count = null
    _.defer => @_fetchCount()

  # Public: Returns the number of unread threads in the user's mailbox
  count: ->
    @_count

  _onNamespaceChanged: ->
    @_onDataChanged()

  _onDataChanged: (change) ->
    return app.dock?.setBadge?("") unless NamespaceStore.current()

    if change && change.objectClass is Thread.name
      @_fetchCountDebounced ?= _.debounce(@_fetchCount, 5000)
      @_fetchCountDebounced()

  _fetchCount: ->
    namespace = NamespaceStore.current()
    return unless namespace

    DatabaseStore.count(Thread, [
      Thread.attributes.namespaceId.equal(namespace.id),
      Thread.attributes.unread.equal(true),
      Thread.attributes.tags.contains('inbox')
    ]).then (count) =>
      return if @_count is count
      @_count = count

      if count > 999
        app.dock?.setBadge?("999+")
      else if count > 0
        app.dock?.setBadge?("#{count}")
      else
        app.dock?.setBadge?("")

      @trigger()

module.exports = UnreadCountStore
