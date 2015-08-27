Reflux = require 'reflux'
_ = require 'underscore'
CategoryStore = require './category-store'
AccountStore = require './account-store'
DatabaseStore = require './database-store'
Actions = require '../actions'
Thread = require '../models/thread'
Folder = require '../models/folder'
Label = require '../models/label'

###
Public: The UnreadCountStore exposes a simple API for getting the number of
unread threads in the user's inbox. If you plugin needs the current unread count,
it's more efficient to observe the UnreadCountStore than retrieve the value
yourself from the database.
###
UnreadCountStore = Reflux.createStore
  init: ->
    @listenTo AccountStore, @_onAccountChanged
    @listenTo DatabaseStore, @_onDataChanged

    atom.config.observe 'core.showUnreadBadge', (val) =>
      if val is true
        @_updateBadgeForCount()
      else
        @_setBadge("")

    @_count = null
    @_fetchCountDebounced ?= _.debounce(@_fetchCount, 5000)
    _.defer => @_fetchCount()

  # Public: Returns the number of unread threads in the user's mailbox
  count: ->
    @_count

  _onAccountChanged: ->
    @_count = 0
    @_updateBadgeForCount(0)
    @trigger()
    @_fetchCount()

  _onDataChanged: (change) ->
    if change && change.objectClass is Thread.name
      @_fetchCountDebounced()

  _fetchCount: ->
    account = AccountStore.current()
    return @_setBadge("") unless account

    if account.usesFolders()
      [CategoryClass, CategoryAttribute] = [Folder, Thread.attributes.folders]
    else if account.usesLabels()
      [CategoryClass, CategoryAttribute] = [Label, Thread.attributes.labels]
    else
      return

    # Note: We can't use the convenience methods on CategoryStore to fetch the
    # category because it may not have been loaded yet
    DatabaseStore.findBy(CategoryClass, {name: 'inbox', accountId: account.id}).then (category) =>
      return unless category

      matchers = [
        Thread.attributes.accountId.equal(account.id),
        Thread.attributes.unread.equal(true),
        CategoryAttribute.contains(category.id)
      ]

      DatabaseStore.count(Thread, matchers).then (count) =>
        return if @_count is count
        @_count = count
        @_updateBadgeForCount(count)
        @trigger()
      .catch (err) =>
        console.warn("Failed to fetch unread count: #{err}")

  _updateBadgeForCount: (count) ->
    return unless atom.isMainWindow()
    return if atom.config.get('core.showUnreadBadge') is false
    if count > 999
      @_setBadge("999+")
    else if count > 0
      @_setBadge("#{count}")
    else
      @_setBadge("")

  _setBadge: (val) ->
    # NOTE: Do not underestimate how long this can take. It's a synchronous
    # remote call and can take ~50+msec.
    ipc = require 'ipc'
    ipc.send('set-badge-value', val)

module.exports = UnreadCountStore
