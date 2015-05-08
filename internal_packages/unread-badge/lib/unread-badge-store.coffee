Reflux = require 'reflux'
_ = require 'underscore-plus'
{DatabaseStore, NamespaceStore, Actions, Thread} = require 'inbox-exports'
remote = require 'remote'
app = remote.require 'app'

AppUnreadCount = null

module.exports =
AppUnreadBadgeStore = Reflux.createStore
  init: ->
    @listenTo NamespaceStore, @_onNamespaceChanged
    @listenTo DatabaseStore, @_onDataChanged
    @_fetchCount()

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
    ]).then (count) ->
      return if AppUnreadCount is count
      AppUnreadCount = count

      if count > 999
        app.dock?.setBadge?("\u221E")
      else if count > 0
        app.dock?.setBadge?("#{count}")
      else
        app.dock?.setBadge?("")
