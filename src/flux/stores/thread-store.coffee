Reflux = require 'reflux'
DatabaseStore = require './database-store'
NamespaceStore = require './namespace-store'
WorkspaceStore = require './workspace-store'
AddRemoveTagsTask = require '../tasks/add-remove-tags'
MarkThreadReadTask = require '../tasks/mark-thread-read'
Actions = require '../actions'
Thread = require '../models/thread'
Message = require '../models/message'
_ = require 'underscore-plus'

ThreadStore = Reflux.createStore
  init: ->
    @_resetInstanceVars()

    @listenTo Actions.selectThreadId, @_onSelectThreadId
    @listenTo Actions.selectTagId, @_onSelectTagId
    @listenTo Actions.archiveAndPrevious, @_onArchiveAndPrevious
    @listenTo Actions.archiveCurrentThread, @_onArchiveCurrentThread
    @listenTo Actions.archiveAndNext, @_onArchiveAndNext
    @listenTo Actions.searchQueryCommitted, @_onSearchCommitted
    @listenTo Actions.selectLayoutMode, @_autoselectForLayoutMode
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
    @_itemsLoading = false

  itemsLoading: -> @_itemsLoading

  fetchFromCache: ->
    return unless @_namespaceId
    return if @_searchQuery # we don't load search results from cache

    oldSelectedThread = @selectedThread()
    oldSelectedIndex = @_items?.indexOf(oldSelectedThread)

    start = Date.now()

    DatabaseStore.findAll(Thread, [
      Thread.attributes.namespaceId.equal(@_namespaceId),
      Thread.attributes.tags.contains(@_tagId)
    ]).limit(100).then (items) =>
      # Now, fetch the messages for each thread. We could do this with a
      # complex join, but then we'd get thread columns repeated over and over.
      # This is reasonably fast because we don't store message bodies in messages
      # anymore.
      itemMessagePromises = {}
      for item in items
        itemMessagePromises[item.id] = DatabaseStore.findAll(Message, [Message.attributes.threadId.equal(item.id)])

      Promise.props(itemMessagePromises).then (results) =>
        for item in items
          item.messageMetadata = results[item.id]

        @_items = items

        # Sometimes we can ask for a thread that's not in the current set
        # of items. If the new set of items includes that thread we asked
        # for, then trigger a new notification.
        if not oldSelectedThread and @_selectedId and @selectedThread()
          # This means in the latest set the thread we were trying to
          # select has been found!
          Actions.selectThreadId(@_selectedId, force: true)
        else if oldSelectedThread && !@selectedThread()
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

        @_autoselectForLayoutMode()

        console.log("Fetching data for thread list took #{Date.now() - start} msec")

        # If we've loaded threads, remove the loading indicator.
        # If there are no results, wait for the API query to finish
        if @_items.length > 0
          @_itemsLoading = false

        @trigger()

  fetchFromAPI: ->
    return unless @_namespaceId

    @_itemsLoading = true
    @trigger()

    doneLoading = =>
      return unless @_itemsLoading
      @_itemsLoading = false
      @trigger()

    if @_searchQuery
      atom.inbox.getThreadsForSearch @_namespaceId, @_searchQuery, (items) =>
        @_items = items
        doneLoading()
    else
      atom.inbox.getThreads(@_namespaceId, {tag: @_tagId}, {success: doneLoading, error: doneLoading})

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
    @fetchFromAPI()

  _onSelectTagId: (id) ->
    return if @_tagId is id
    @_tagId = id

    @_items = []
    @trigger()
    @fetchFromCache()
    @fetchFromAPI()

  _onSelectThreadId: (id, {force}={}) ->
    return if @_selectedId is id and not force
    @_selectedId = id

    thread = @selectedThread()
    if thread && thread.isUnread()
      Actions.queueTask(new MarkThreadReadTask(thread.id))

    @trigger()

  _onArchiveCurrentThread: ({silent}={}) ->
    thread = @selectedThread()
    return unless thread
    @_archive(thread.id)
    @_selectedId = null
    if not silent
      @trigger()
      Actions.popSheet()
      Actions.selectThreadId(null)

  _archive: (threadId) ->
    Actions.postNotification({message: "Archived thread", type: 'success'})
    task = new AddRemoveTagsTask(threadId, ['archive'], ['inbox'])
    Actions.queueTask(task)

  _threadOffsetFromCurrentBy: (offset=0) ->
    thread = @selectedThread()
    index = @_items.indexOf(thread)
    return null if index is -1
    index += offset
    index = Math.min(Math.max(index, 0), @_items.length - 1)
    return @_items[index]

  _onArchiveAndPrevious: ->
    return unless @_selectedId
    newSelectedId = @_threadOffsetFromCurrentBy(-1)?.id
    @_onArchiveCurrentThread(silent: true)
    Actions.selectThreadId(newSelectedId)

  _onArchiveAndNext: ->
    return unless @_selectedId
    newSelectedId = @_threadOffsetFromCurrentBy(1)?.id
    @_onArchiveCurrentThread(silent: true)
    Actions.selectThreadId(newSelectedId)

  _autoselectForLayoutMode: ->
    if WorkspaceStore.selectedLayoutMode() is "split" and not @selectedThread()
      _.defer => Actions.selectThreadId(@_items[0]?.id)

  # Accessing Data

  selectedTagId: ->
    @_tagId

  selectedId: ->
    @_selectedId

  # It is not uncommon for the @_selectedId to exist but the
  # @selectedThread to be null. This happens when we try and select a
  # thread that's not in the current result set. As the result set
  # changes, this condition may change as well.
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
