Reflux = require 'reflux'
_ = require 'underscore-plus'

{DatabaseStore,
 NamespaceStore,
 WorkspaceStore,
 AddRemoveTagsTask,
 FocusedTagStore,
 FocusedThreadStore,
 Actions,
 Utils,
 Thread,
 Message} = require 'inbox-exports'

ThreadStore = Reflux.createStore
  init: ->
    @_resetInstanceVars()

    @listenTo Actions.searchQueryCommitted, @_onSearchCommitted
    @listenTo Actions.selectLayoutMode, @_autoselectForLayoutMode

    @listenTo Actions.archiveAndPrevious, @_onArchiveAndPrev
    @listenTo Actions.archiveAndNext, @_onArchiveAndNext
    @listenTo Actions.archiveCurrentThread, @_onArchive

    @listenTo DatabaseStore, @_onDataChanged
    @listenTo FocusedTagStore, @_onFocusedTagChanged
    @listenTo NamespaceStore, @_onNamespaceChanged

    @fetchFromCache()
    @_lastQuery = null

  _resetInstanceVars: ->
    @_items = []
    @_namespaceId = null
    @_searchQuery = null
    @_itemsLoading = false

  itemsLoading: -> @_itemsLoading

  fetchFromCache: (options = {}) ->
    tagId = FocusedTagStore.tagId()
    start = Date.now()
    
    # we don't load search results from cache
    return unless @_namespaceId
    return if @_searchQuery or !tagId


    # If we know that only a Thread model has changed in the database,
    # or that only messages of a few specific threads have changed,
    # populate a hash of message metadata that can save us queries later.
    knownMessages = {}
    if options.shallow
      for item in @_items
        continue if options.invalid and item.id in options.invalid
        knownMessages[item.id] = item.messageMetadata

    matchers = []
    matchers.push Thread.attributes.namespaceId.equal(@_namespaceId)
    if tagId and tagId isnt "*"
      matchers.push Thread.attributes.tags.contains(tagId)

    DatabaseStore.findAll(Thread).where(matchers).limit(100).then (items) =>
      # Now, fetch the messages for each thread. We could do this with a
      # complex join, but then we'd get thread columns repeated over and over.
      # This is reasonably fast because we don't store message bodies in messages
      # anymore.
      itemMessagePromises = {}
      for item in items
        itemMessagePromises[item.id] ?= knownMessages[item.id]
        itemMessagePromises[item.id] ?= DatabaseStore.findAll(Message, [Message.attributes.threadId.equal(item.id)])

      Promise.props(itemMessagePromises).then (results) =>
        for item in items
          item.messageMetadata = results[item.id]

          # Prevent anything from mutating these objects or their nested objects.
          # Accidentally modifying items somewhere downstream (in a component)
          # can trigger awful re-renders
          Utils.modelFreeze(item)

        @_items = items
        @_autoselectForLayoutMode()

        console.log("Thread list refresh took #{Date.now() - start} msec.\
                     Shallow: #{options?.shallow}. Invalid: #{options?.invalid?.length}")

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
      params = {}
      tagId = FocusedTagStore.tagId()
      if tagId and tagId isnt "*"
        params = {tag: tagId}
      atom.inbox.getThreads(@_namespaceId, params, {success: doneLoading, error: doneLoading})

  # Inbound Events

  _onNamespaceChanged: ->
    @_namespaceId = NamespaceStore.current()?.id
    @_items = []
    @trigger(@)

    Actions.focusThread(null)
    @fetchFromCache()
    @fetchFromAPI()

  _onDataChanged: (change) ->
    if change.objectClass is Thread.name
      @fetchFromCache({shallow: true})

    if change.objectClass is Message.name
      threadIds = _.uniq _.map change.objects, (msg) -> msg.threadId
      @fetchFromCache({shallow: true, invalid: threadIds})

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

  _onFocusedTagChanged: (tag) ->
    @_items = []
    @trigger()
    @fetchFromCache()
    @fetchFromAPI()

  _onArchive: ->
    @_archiveAndShiftBy('auto')

  _onArchiveAndPrev: ->
    @_archiveAndShiftBy(-1)

  _onArchiveAndNext: ->
    @_archiveAndShiftBy(1)

  _archiveAndShiftBy: (offset) ->
    layoutMode = WorkspaceStore.selectedLayoutMode()
    selected = FocusedThreadStore.thread()
    return unless selected

    # Determine the index of the current thread
    index = -1
    for item, idx in @_items
      if item.id is selected.id
        index = idx
        break
    return if index is -1

    # Archive the current thread
    task = new AddRemoveTagsTask(selected.id, ['archive'], ['inbox'])
    Actions.postNotification({message: "Archived thread", type: 'success'})
    Actions.queueTask(task)

    if offset is 'auto'
      if layoutMode is 'list'
        # If the user is in list mode, return to the thread lit
        Actions.focusThread(null)
        return
      else if layoutMode is 'split'
        # If the user is in split mode, automatically select another
        # thead when they archive the current one. We move up if the one above
        # the current thread is unread. Otherwise move down.
        if @_items[index - 1]?.isUnread()
          offset = -1
        else
          offset = 1

    index = Math.min(Math.max(index + offset, 0), @_items.length - 1)
    Actions.focusThread(@_items[index])

  _autoselectForLayoutMode: ->
    selectedId = FocusedThreadStore.threadId()
    if WorkspaceStore.selectedLayoutMode() is "split" and not selectedId
      _.defer => Actions.focusThread(@_items[0])

  # Accessing Data

  items: ->
    @_items

module.exports = ThreadStore
