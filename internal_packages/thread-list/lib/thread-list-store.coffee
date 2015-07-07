Reflux = require 'reflux'
_ = require 'underscore'

{DatabaseStore,
 DatabaseView,
 SearchView,
 NamespaceStore,
 WorkspaceStore,
 AddRemoveTagsTask,
 FocusedTagStore,
 FocusedContentStore,
 Actions,
 Utils,
 Thread,
 Message} = require 'nylas-exports'

# Public: A mutable text container with undo/redo support and the ability to
# annotate logical regions in the text.
#
module.exports =
ThreadListStore = Reflux.createStore
  init: ->
    @_resetInstanceVars()

    @listenTo Actions.searchQueryCommitted, @_onSearchCommitted
    @listenTo Actions.selectLayoutMode, @_autofocusForLayoutMode

    @listenTo Actions.archiveAndPrevious, @_onArchiveAndPrev
    @listenTo Actions.archiveAndNext, @_onArchiveAndNext
    @listenTo Actions.archiveSelection, @_onArchiveSelection
    @listenTo Actions.archive, @_onArchive

    @listenTo Actions.toggleStarSelection, @_onToggleStarSelection
    @listenTo Actions.toggleStarFocused, @_onToggleStarFocused

    @listenTo DatabaseStore, @_onDataChanged
    @listenTo FocusedTagStore, @_onTagChanged
    @listenTo NamespaceStore, @_onNamespaceChanged

    @createView()

  _resetInstanceVars: ->
    @_lastQuery = null
    @_searchQuery = null

  view: ->
    @_view

  setView: (view) ->
    @_viewUnlisten() if @_viewUnlisten
    @_view = view

    @_viewUnlisten = view.listen ->
      @trigger(@)
      @_autofocusForLayoutMode()
    ,@

    @trigger(@)

  createView: ->
    tagId = FocusedTagStore.tagId()
    namespaceId = NamespaceStore.current()?.id

    if @_searchQuery
      @setView(new SearchView(@_searchQuery, namespaceId))

    else if namespaceId and tagId
      matchers = []
      matchers.push Thread.attributes.namespaceId.equal(namespaceId)
      matchers.push Thread.attributes.tags.contains(tagId) if tagId isnt "*"
      view = new DatabaseView Thread, {matchers}, (ids) =>
        DatabaseStore.findAll(Message).where(Message.attributes.threadId.in(ids)).then (messages) ->
          messagesByThread = {}
          for id in ids
            messagesByThread[id] = []
          for message in messages
            messagesByThread[message.threadId].push message
          messagesByThread
      @setView(view)

    Actions.setFocus(collection: 'thread', item: null)

  # Inbound Events

  _onTagChanged: ->
    @createView()

  _onNamespaceChanged: ->
    namespaceId = NamespaceStore.current()?.id
    namespaceMatcher = (m) ->
      m.attribute() is Thread.attributes.namespaceId and m.value() is namespaceId

    return if @view and _.find(@view.matchers, namespaceMatcher)
    @createView()

  _onSearchCommitted: (query) ->
    return if @_searchQuery is query
    @_searchQuery = query
    @createView()

  _onDataChanged: (change) ->
    if change.objectClass is Thread.name
      @_view.invalidate({change: change, shallow: true})

    if change.objectClass is Message.name
      threadIds = _.uniq _.map change.objects, (m) -> m.threadId
      @_view.invalidateMetadataFor(threadIds)

  _onToggleStarSelection: ->
    selectedThreads = @_view.selection.items()
    focusedId = FocusedContentStore.focusedId('thread')
    keyboardId = FocusedContentStore.keyboardCursorId('thread')

    oneAlreadyStarred = false
    for thread in selectedThreads
      if thread.hasTagId('starred')
        oneAlreadyStarred = true

    if oneAlreadyStarred
      task = new AddRemoveTagsTask(selectedThreads, [], ['starred'])
    else
      task = new AddRemoveTagsTask(selectedThreads, ['starred'], [])
    Actions.queueTask(task)

  _onToggleStarFocused: ->
    focused = FocusedContentStore.focused('thread')
    return unless focused

    if focused.isStarred()
      task = new AddRemoveTagsTask(focused, [], ['starred'])
    else
      task = new AddRemoveTagsTask(focused, ['starred'], [])
    Actions.queueTask(task)

  _onArchive: ->
    @_archiveAndShiftBy('auto')

  _onArchiveSelection: ->
    selectedThreads = @_view.selection.items()
    selectedThreadIds = selectedThreads.map (thread) -> thread.id
    focusedId = FocusedContentStore.focusedId('thread')
    keyboardId = FocusedContentStore.keyboardCursorId('thread')

    task = new AddRemoveTagsTask(selectedThreads, ['archive'], ['inbox'])
    task.waitForPerformLocal().then =>
      if focusedId in selectedThreadIds
        Actions.setFocus(collection: 'thread', item: null)
      if keyboardId in selectedThreadIds
        Actions.setCursorPosition(collection: 'thread', item: null)

    Actions.queueTask(task)
    @_view.selection.clear()

  _onArchiveAndPrev: ->
    @_archiveAndShiftBy(-1)

  _onArchiveAndNext: ->
    @_archiveAndShiftBy(1)

  _archiveAndShiftBy: (offset) ->
    layoutMode = WorkspaceStore.layoutMode()
    focused = FocusedContentStore.focused('thread')
    explicitOffset = if offset is "auto" then false else true

    return unless focused

    # Determine the current index
    index = @_view.indexOfId(focused.id)
    return if index is -1

    # Determine the next index we want to move to
    if offset is 'auto'
      if @_view.get(index - 1)?.isUnread()
        offset = -1
      else
        offset = 1

    index = Math.min(Math.max(index + offset, 0), @_view.count() - 1)
    nextKeyboard = nextFocus = @_view.get(index)

    # Remove the current thread from selection
    @_view.selection.remove(focused)

    # If the user is in list mode and archived without specifically saying
    # "archive and next" or "archive and prev", return to the thread list
    # instead of focusing on the next message.
    if layoutMode is 'list' and not explicitOffset
      nextFocus = null

    # Archive the current thread
    task = new AddRemoveTagsTask(focused, ['archive'], ['inbox'])
    task.waitForPerformLocal().then ->
      Actions.setFocus(collection: 'thread', item: nextFocus)
      Actions.setCursorPosition(collection: 'thread', item: nextKeyboard)
    Actions.queueTask(task)

  _autofocusForLayoutMode: ->
    layoutMode = WorkspaceStore.layoutMode()
    focused = FocusedContentStore.focused('thread')
    if layoutMode is 'split' and not focused and @_view.selection.count() is 0
      item = @_view.get(0)
      _.defer =>
        Actions.setFocus({collection: 'thread', item: item})
