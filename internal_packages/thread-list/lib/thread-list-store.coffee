_ = require 'underscore'
NylasStore = require 'nylas-store'

{Thread,
 Message,
 Actions,
 SearchView,
 DatabaseView,
 DatabaseStore,
 AccountStore,
 WorkspaceStore,
 ChangeStarredTask,
 FocusedContentStore,
 ArchiveThreadHelper,
 TaskQueueStatusStore,
 FocusedCategoryStore} = require 'nylas-exports'

# Public: A mutable text container with undo/redo support and the ability
# to annotate logical regions in the text.
class ThreadListStore extends NylasStore
  constructor: ->
    @_resetInstanceVars()

    @listenTo Actions.searchQueryCommitted, @_onSearchCommitted

    @listenTo Actions.archiveAndPrevious, @_onArchiveAndPrev
    @listenTo Actions.archiveAndNext, @_onArchiveAndNext

    @listenTo Actions.archiveSelection, @_onArchiveSelection
    @listenTo Actions.moveThreads, @_onMoveThreads

    @listenTo Actions.archive, @_onArchive
    @listenTo Actions.moveThread, @_onMoveThread

    @listenTo Actions.toggleStarSelection, @_onToggleStarSelection
    @listenTo Actions.toggleStarFocused, @_onToggleStarFocused

    @listenTo DatabaseStore, @_onDataChanged
    @listenTo AccountStore, @_onAccountChanged
    @listenTo FocusedCategoryStore, @_onCategoryChanged

    atom.config.observe 'core.workspace.mode', => @_autofocusForLayoutMode()

    # We can't create a @view on construction because the CategoryStore
    # has hot yet been populated from the database with the list of
    # categories and their corresponding ids. Once that is ready, the
    # CategoryStore will trigger, which will update the
    # FocusedCategoryStore, which will cause us to create a new
    # @view.

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
    categoryId = FocusedCategoryStore.categoryId()
    account = AccountStore.current()
    return unless account

    if @_searchQuery
      @setView(new SearchView(@_searchQuery, account.id))

    else if account.id and categoryId
      matchers = []
      matchers.push Thread.attributes.accountId.equal(account.id)

      if account.usesLabels()
        matchers.push Thread.attributes.labels.contains(categoryId)
      else if account.usesFolders()
        matchers.push Thread.attributes.folders.contains(categoryId)
      else
        throw new Error("Invalid organizationUnit")
      view = new DatabaseView Thread, {matchers}, (ids) =>
        DatabaseStore.findAll(Message)
        .where(Message.attributes.threadId.in(ids))
        .where(Message.attributes.accountId.equal(account.id))
        .then (messages) ->
          messagesByThread = {}
          for id in ids
            messagesByThread[id] = []
          for message in messages
            messagesByThread[message.threadId].push message
          messagesByThread
      @setView(view)

    Actions.setFocus(collection: 'thread', item: null)

  # Inbound Events

  _onCategoryChanged: ->
    @createView()

  _onAccountChanged: ->
    accountId = AccountStore.current()?.id
    accountMatcher = (m) ->
      m.attribute() is Thread.attributes.accountId and m.value() is accountId

    return if @_view and _.find(@_view.matchers, accountMatcher)
    @createView()

  _onSearchCommitted: (query) ->
    return if @_searchQuery is query
    @_searchQuery = query
    @createView()

  _onDataChanged: (change) ->
    return unless @_view

    if change.objectClass is Thread.name
      @_view.invalidate({change: change, shallow: true})

    if change.objectClass is Message.name
      # Important: Until we optimize this so that it detects the set change
      # and avoids a query, this should be debounced since it's very unimportant
      _.defer =>
        threadIds = _.uniq _.map change.objects, (m) -> m.threadId
        @_view.invalidateMetadataFor(threadIds)

  _onToggleStarSelection: ->
    threads = @_view.selection.items()
    focusedId = FocusedContentStore.focusedId('thread')
    keyboardId = FocusedContentStore.keyboardCursorId('thread')

    oneAlreadyStarred = false
    for thread in threads
      if thread.starred
        oneAlreadyStarred = true

    starred = not oneAlreadyStarred
    task = new ChangeStarredTask({threads, starred})
    Actions.queueTask(task)

  _onToggleStarFocused: ->
    focused = FocusedContentStore.focused('thread')
    cursor = FocusedContentStore.keyboardCursor('thread')
    if focused
      task = new ChangeStarredTask(thread: focused, starred: !focused.starred)
    else if cursor
      task = new ChangeStarredTask(thread: cursor, starred: !cursor.starred)

    if task
      Actions.queueTask(task)

  _onArchive: ->
    @_archiveAndShiftBy('auto')

  _onArchiveAndPrev: ->
    @_archiveAndShiftBy(-1)

  _onArchiveAndNext: ->
    @_archiveAndShiftBy(1)

  _archiveAndShiftBy: (offset) ->
    focused = FocusedContentStore.focused('thread')
    return unless focused
    task = ArchiveThreadHelper.getArchiveTask([focused])
    @_moveAndShiftBy(offset, task)

  _onMoveThread: (thread, task) ->
    @_moveAndShiftBy('auto', task)

  _onMoveThreads: (threads, task) ->
    selectedThreadIds = threads.map (thread) -> thread.id
    focusedId = FocusedContentStore.focusedId('thread')
    keyboardId = FocusedContentStore.keyboardCursorId('thread')

    TaskQueueStatusStore.waitForPerformLocal(task).then =>
      if focusedId in selectedThreadIds
        Actions.setFocus(collection: 'thread', item: null)
      if keyboardId in selectedThreadIds
        Actions.setCursorPosition(collection: 'thread', item: null)

    Actions.queueTask(task)
    @_view.selection.clear()

  _onArchiveSelection: ->
    selectedThreads = @_view.selection.items()
    task = ArchiveThreadHelper.getArchiveTask(selectedThreads)
    @_onMoveThreads(selectedThreads, task)

  _moveAndShiftBy: (offset, task) ->
    layoutMode = WorkspaceStore.layoutMode()
    focused = FocusedContentStore.focused('thread')
    explicitOffset = if offset is "auto" then false else true

    return unless focused

    # Determine the current index
    index = @_view.indexOfId(focused.id)
    return if index is -1

    # Determine the next index we want to move to
    if offset is 'auto'
      if @_view.get(index - 1)?.unread
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
    TaskQueueStatusStore.waitForPerformLocal(task).then =>
      Actions.setFocus(collection: 'thread', item: nextFocus)
      Actions.setCursorPosition(collection: 'thread', item: nextKeyboard)
    Actions.queueTask(task)

  _autofocusForLayoutMode: ->
    return unless @_view
    layoutMode = WorkspaceStore.layoutMode()
    focused = FocusedContentStore.focused('thread')
    if layoutMode is 'split' and not focused and @_view.selection.count() is 0
      item = @_view.get(0)
      _.defer =>
        Actions.setFocus({collection: 'thread', item: item})

module.exports = new ThreadListStore()
