Reflux = require 'reflux'
DatabaseStore = require './database-store'
NamespaceStore = require './namespace-store'
Actions = require '../actions'
Thread = require '../models/thread'
_ = require 'underscore-plus'

ThreadStore = Reflux.createStore
  init: ->
    @_resetInstanceVars()

    @listenTo Actions.selectThreadId, @_onSelectThreadId
    @listenTo Actions.selectTagId, @_onSelectTagId
    @listenTo Actions.searchQueryCommitted, @_onSearchCommitted
    @listenTo DatabaseStore, @_onDataChanged
    @listenTo NamespaceStore, -> @_onNamespaceChanged()
    @fetchFromCache()
    @_lastQuery = null

  _resetInstanceVars: ->
    @_items = []
    @_selectedId = null
    @_namespaceId = null
    @_tagId = null
    @_searchQuery = null

  fetchFromCache: ->
    return unless @_namespaceId
    return if @_searchQuery # we don't load search results from cache

    oldSelectedThread = @selectedThread()
    oldSelectedIndex = @_items?.indexOf(oldSelectedThread)

    DatabaseStore.findAll(Thread, [
      Thread.attributes.namespaceId.equal(@_namespaceId),
      Thread.attributes.tags.contains(@_tagId)
    ]).limit(100).then (items) =>
      @_items = items

      if oldSelectedThread && !@selectedThread()
        # The previously selected item is no longer in the set
        oldSelectedIndex = Math.max(0, Math.min(oldSelectedIndex, @_items.length - 1))
        thread = @_items[oldSelectedIndex]
        threadBefore = @_items[oldSelectedIndex-1]

        # Often when users read mail they go from oldest->newest and
        # selecting the thread taking the place of the removed one would mean
        # selecting an already-read thread. Copy behavior of Mail.app and move
        # to the item ABOVE the previously selected item when it's unread,
        # otherwise move down.
        if thread && !thread.isUnread() && threadBefore && threadBefore.isUnread()
          thread = threadBefore
        if thread
          newSelectedId = thread.id
        else
          newSelectedId = null
        Actions.selectThreadId(newSelectedId)

      @trigger()

  fetchFromAPI: ->
    return unless @_namespaceId
    if @_searchQuery
      atom.inbox.getThreadsForSearch @_namespaceId, @_searchQuery, (items) =>
        @_items = items
        @trigger()
    else
      atom.inbox.getThreads(@_namespaceId, {tag: @_tagId})

  # Inbound Events

  _onNamespaceChanged: ->
    @_namespaceId = NamespaceStore.current()?.id
    @_items = []
    @trigger(@)

    Actions.selectThreadId(null)
    @fetchFromCache()
    @fetchFromAPI()

  _onDataChanged: (change) ->
    return unless change.objectClass == Thread.name
    @fetchFromCache()

  _onSearchCommitted: (query) ->
    if query.length > 0
      @_searchQuery = query
      @_items = []
      @trigger()
    else
      return if not @_lastQuery? or @_lastQuery.length == 0
      @_searchQuery = null
      @fetchFromCache()

    @_lastQuery = query
    Actions.selectThreadId(null)
    @fetchFromAPI()

  _onSelectTagId: (id) ->
    @_tagId = id
    Actions.selectThreadId(null)
    @fetchFromCache()
    @fetchFromAPI()

  _onSelectThreadId: (id) ->
    return if @_selectedId == id
    @_selectedId = id

    thread = @selectedThread()
    if thread && thread.isUnread()
      thread.markAsRead()

    @trigger()

  # Accessing Data

  selectedTagId: ->
    @_tagId

  selectedId: ->
    @_selectedId

  selectedThread: ->
    return null unless @_selectedId
    _.find @_items, (thread) => thread.id == @_selectedId

  isFirstThread: ->
    @_items[0]?.id is @_selectedId and @_selectedId?

  isLastThread: ->
    @_items[@_items.length-1]?.id is @_selectedId and @_selectedId?

  items: ->
    @_items

module.exports = ThreadStore
