Reflux = require 'reflux'
_ = require 'underscore'
NylasStore = require 'nylas-store'
FocusedMailViewStore = require './focused-mail-view-store'
CategoryStore = require './category-store'
ThreadCountsStore = require './thread-counts-store'

class UnreadBadgeStore extends NylasStore

  constructor: ->
    @_count = 0

    @listenTo CategoryStore, @_updateCount
    @listenTo ThreadCountsStore, @_updateCount
    NylasEnv.config.observe 'core.notifications.unreadBadge', (val) =>
      if val is true
        @_setBadgeForCount()
      else
        @_setBadge("")

    @_updateCount()

  # Public: Returns the number of unread threads in the user's mailbox
  count: ->
    @_count

  _updateCount: =>
    account = FocusedMailViewStore.mailView()?.account
    category = CategoryStore.getStandardCategory(account, 'inbox')
    if category
      count = ThreadCountsStore.unreadCountForCategoryId(category.id) ? 0
    else
      count = 0

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
