Reflux = require 'reflux'
_ = require 'underscore'
NylasStore = require 'nylas-store'
FocusedPerspectiveStore = require './focused-perspective-store'
ThreadCountsStore = require './thread-counts-store'

class UnreadBadgeStore extends NylasStore

  constructor: ->
    @_count = FocusedPerspectiveStore.current().threadUnreadCount()

    @listenTo FocusedPerspectiveStore, @_updateCount
    @listenTo ThreadCountsStore, @_updateCount
    NylasEnv.config.onDidChange 'core.notifications.unreadBadge', ({newValue}) =>
      if newValue is true
        @_setBadgeForCount()
      else
        @_setBadge("")

    @_updateCount()

  # Public: Returns the number of unread threads in the user's mailbox
  count: ->
    @_count

  _updateCount: =>
    current = FocusedPerspectiveStore.current()
    if current.isInbox()
      count = current.threadUnreadCount()
      return if @_count is count
      @_count = count
      @_setBadgeForCount()
      @trigger()

  _setBadgeForCount: =>
    return unless NylasEnv.config.get('core.notifications.unreadBadge')
    return unless NylasEnv.isMainWindow() or NylasEnv.inSpecMode()

    if @_count > 999
      @_setBadge("999+")
    else if @_count > 0
      @_setBadge("#{@_count}")
    else
      @_setBadge("")

  _setBadge: (val) =>
    require('electron').ipcRenderer.send('set-badge-value', val)

module.exports = new UnreadBadgeStore()
