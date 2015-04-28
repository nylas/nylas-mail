Reflux = require 'reflux'
_ = require 'underscore-plus'

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
 Message} = require 'inbox-exports'

# Public: A mutable text container with undo/redo support and the ability to
# annotate logical regions in the text.
#
module.exports =
ThreadListStore = Reflux.createStore
  init: ->
    @_resetInstanceVars()
    @_afterViewUpdate = []

    @listenTo Actions.searchQueryCommitted, @_onSearchCommitted
    @listenTo Actions.selectLayoutMode, @_autofocusForLayoutMode

    @listenTo Actions.archiveAndPrevious, @_onArchiveAndPrev
    @listenTo Actions.archiveAndNext, @_onArchiveAndNext
    @listenTo Actions.archiveSelection, @_onArchiveSelection
    @listenTo Actions.archive, @_onArchive
    @listenTo Actions.selectThreads, @_onSetSelection

    @listenTo DatabaseStore, @_onDataChanged
    @listenTo FocusedTagStore, @_onTagChanged
    @listenTo NamespaceStore, @_onNamespaceChanged

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
      fn() for fn in @_afterViewUpdate
      @_afterViewUpdate = []
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
      @setView new DatabaseView Thread, {matchers}, (item) ->
        DatabaseStore.findAll(Message, {threadId: item.id})

    Actions.focusInCollection(collection: 'thread', item: null)

  # Inbound Events

  _onTagChanged: -> @createView()
  _onNamespaceChanged: -> @createView()

  _onSearchCommitted: (query) ->
    return if @_searchQuery is query
    @_searchQuery = query
    @createView()

  _onSetSelection: (threads) ->
    @_view.selection.set(threads)

  _onDataChanged: (change) ->
    if change.objectClass is Thread.name
      @_view.invalidate({changed: change.objects, shallow: true})

    if change.objectClass is Message.name
      threadIds = _.uniq _.map change.objects, (m) -> m.threadId
      @_view.invalidateMetadataFor(threadIds)

  _onArchive: ->
    @_archiveAndShiftBy('auto')

  _onArchiveSelection: ->
    selected = @_view.selection.items()
    focusedId = FocusedContentStore.focusedId('thread')
    keyboardId = FocusedContentStore.keyboardCursorId('thread')

    for thread in selected
      task = new AddRemoveTagsTask(thread, ['archive'], ['inbox'])
      Actions.queueTask(task)
      if thread.id is focusedId
        Actions.focusInCollection(collection: 'thread', item: null)
      if thread.id is keyboardId
        Actions.focusKeyboardInCollection(collection: 'thread', item: null)

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

    # Archive the current thread
    task = new AddRemoveTagsTask(focused, ['archive'], ['inbox'])
    Actions.queueTask(task)
    Actions.postNotification({message: "Archived thread", type: 'success'})

    # Remove the current thread from selection
    @_view.selection.remove(focused)

    # If the user is in list mode and archived without specifically saying
    # "archive and next" or "archive and prev", return to the thread list
    # instead of focusing on the next message.
    if layoutMode is 'list' and not explicitOffset
      nextFocus = null

    @_afterViewUpdate.push ->
      Actions.focusInCollection(collection: 'thread', item: nextFocus)
      Actions.focusKeyboardInCollection(collection: 'thread', item: nextKeyboard)

  _autofocusForLayoutMode: ->
    focusedId = FocusedContentStore.focusedId('thread')
    if WorkspaceStore.layoutMode() is "split" and not focusedId
      _.defer => Actions.focusInCollection(collection: 'thread', item: @_view.get(0))
