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
    return @_setBadge("") unless NamespaceStore.current()

    if change && change.objectClass is Thread.name
      @_fetchCountDebounced ?= _.debounce(@_fetchCount, 5000)
      @_fetchCountDebounced()

  _fetchCount: ->
    namespace = NamespaceStore.current()
    return unless namespace

    matchers = [
      Thread.attributes.namespaceId.equal(namespace.id),
      Thread.attributes.unread.equal(true),
    ]
    if namespace.usesFolders()
      matchers.push(Thread.attributes.folders.contains('inbox'))
    else if namespace.usesLabels()
      matchers.push(Thread.attributes.labels.contains('inbox'))
    else
      return

    DatabaseStore.count(Thread, matchers).then (count) =>
      return if @_count is count
      @_count = count
      @_updateBadgeForCount(count)
      @trigger()
    .catch (err) =>
      console.warn("Failed to fetch unread count: #{err}")

  _updateBadgeForCount: (count) ->
    return unless atom.isMainWindow()
    if count > 999
      @_setBadge("999+")
    else if count > 0
      @_setBadge("#{count}")
    else
      @_setBadge("")

  _setBadge: (val) ->
    app.dock?.setBadge?(val)

module.exports = UnreadCountStore
