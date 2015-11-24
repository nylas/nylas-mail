Reflux = require 'reflux'
_ = require 'underscore'
NylasStore = require 'nylas-store'
CategoryStore = require './category-store'
DatabaseStore = require './database-store'
ThreadCountsStore = require './thread-counts-store'

class UnreadBadgeStore extends NylasStore

  constructor: ->
    @listenTo CategoryStore, @_onCategoriesChanged
    @listenTo ThreadCountsStore, @_onCountsChanged
    @_category = CategoryStore.getStandardCategory('inbox')

    NylasEnv.config.observe 'core.showUnreadBadge', (val) =>
      if val is true
        @_setBadgeForCount(@_count)
      else
        @_setBadge("")

    @_updateCount()

  # Public: Returns the number of unread threads in the user's mailbox
  count: ->
    @_count

  _onCategoriesChanged: =>
    cat = CategoryStore.getStandardCategory('inbox')
    return if @_category and cat.id is @_category.id
    @_category = cat
    @_updateCount()

  _onCountsChanged: =>
    @_updateCount()

  _updateCount: =>
    return unless NylasEnv.isMainWindow()
    return unless @_category

    count = ThreadCountsStore.unreadCountForCategoryId(@_category.id) ? 0
    return if @_count is count

    @_count = count
    @_setBadgeForCount(count)
    @trigger()

  _setBadgeForCount: (count) =>
    if count > 999
      @_setBadge("999+")
    else if count > 0
      @_setBadge("#{count}")
    else
      @_setBadge("")

  _setBadge: (val) =>
    # NOTE: Do not underestimate how long this can take. It's a synchronous
    # remote call and can take ~50+msec.
    return if NylasEnv.config.get('core.showUnreadBadge') is false
    require('ipc').send('set-badge-value', val)

module.exports = new UnreadBadgeStore()
