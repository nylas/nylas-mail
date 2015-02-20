Reflux = require 'reflux'
_ = require 'underscore-plus'
{DatabaseStore, NamespaceStore, Actions, Tag} = require 'inbox-exports'
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
    return if change && change.objectClass != Tag.name
    return app.dock?.setBadge?("") unless NamespaceStore.current()
    @_updateBadge()

  _updateBadge: ->
    DatabaseStore.find(Tag, 'inbox').then (inbox) ->
      return unless inbox
      count = inbox.unreadCount
      if count > 999
        app.dock?.setBadge?("\u221E")
      else if count > 0
        app.dock?.setBadge?("#{count}")
      else
        app.dock?.setBadge?("")
