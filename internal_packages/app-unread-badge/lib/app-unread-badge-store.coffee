Reflux = require 'reflux'
_ = require 'underscore-plus'
{DatabaseStore, NamespaceStore, Actions, Thread} = require 'inbox-exports'
remote = require 'remote'
app = remote.require 'app'

module.exports =
AppUnreadBadgeStore = Reflux.createStore
  init: ->
    @listenTo NamespaceStore, @_onNamespaceChanged
    @listenTo DatabaseStore, @_onDataChanged

  _onNamespaceChanged: ->
    @_onDataChanged()

  _onDataChanged: (change) ->
    return if change && change.objectClass != Thread.name
    return app.dock?.setBadge?("") unless NamespaceStore.current()
    @_updateBadgeDebounced()

  _updateBadge: ->
    DatabaseStore.count(Thread, [
      Thread.attributes.namespaceId.equal(NamespaceStore.current()?.id),
      Thread.attributes.unread.equal(true),
      Thread.attributes.tags.contains('inbox')
    ]).then (count) ->
      if count > 999
        app.dock?.setBadge?("\u221E")
      else if count > 0
        app.dock?.setBadge?("#{count}")
      else
        app.dock?.setBadge?("")

  _updateBadgeDebounced: _.debounce ->
    @_updateBadge()
  , 750
