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
 FocusedMailViewStore} = require 'nylas-exports'

# Public: A mutable text container with undo/redo support and the ability
# to annotate logical regions in the text.
class ThreadListStore extends NylasStore
  constructor: ->
    @_resetInstanceVars()

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
    @listenTo FocusedMailViewStore, @_onMailViewChanged

    # We can't create a @view on construction because the CategoryStore
    # has hot yet been populated from the database with the list of
    # categories and their corresponding ids. Once that is ready, the
    # CategoryStore will trigger, which will update the
    # FocusedMailViewStore, which will cause us to create a new
    # @view.

  _resetInstanceVars: ->
    @_lastQuery = null

  view: ->
    @_view

  setView: (view) ->
    @_viewUnlisten() if @_viewUnlisten
    @_view = view

    @_viewUnlisten = view.listen ->
      @trigger(@)
    ,@

    @trigger(@)

  createView: ->
    mailViewFilter = FocusedMailViewStore.mailView()
    account = AccountStore.current()
    return unless account and mailViewFilter

    if mailViewFilter.searchQuery
      @setView(new SearchView(mailViewFilter.searchQuery, account.id))
    else
      matchers = []
      matchers.push Thread.attributes.accountId.equal(account.id)
      matchers = matchers.concat(mailViewFilter.matchers())

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

      if WorkspaceStore.layoutMode() is 'split'
          # Set up a one-time listener to focus an item in the new view
        unlisten = view.listen ->
          if view.loaded()
            Actions.setFocus(collection: 'thread', item: view.get(0))
            unlisten()

      @setView(view)

    Actions.setFocus(collection: 'thread', item: null)

  # Inbound Events

  _onMailViewChanged: ->
    @createView()

  _onAccountChanged: ->
    accountId = AccountStore.current()?.id
    accountMatcher = (m) ->
      m.attribute() is Thread.attributes.accountId and m.value() is accountId

    return if @_view and _.find(@_view.matchers, accountMatcher)
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

  _onArchiveSelection: ->
    selectedThreads = @_view.selection.items()
    task = ArchiveThreadHelper.getArchiveTask(selectedThreads)
    @_onMoveThreads(selectedThreads, task)

  _onMoveThread: (thread, task) ->
    @_moveAndShiftBy('auto', task)

  _onMoveThreads: (threads, task) ->
    threadIds = threads.map (thread) -> thread.id
    focusedId = FocusedContentStore.focusedId('thread')
    keyboardId = FocusedContentStore.keyboardCursorId('thread')

    if focusedId in threadIds
      changeFocused = true
    if keyboardId in threadIds
      changeKeyboardCursor = true

    if changeFocused or changeKeyboardCursor
      newFocusIndex = Number.MAX_VALUE
      for thread in threads
        newFocusIndex = Math.min(newFocusIndex, @_view.indexOfId(thread.id))

    TaskQueueStatusStore.waitForPerformLocal(task).then =>
      layoutMode = WorkspaceStore.layoutMode()
      if changeFocused
        item = @_view.get(newFocusIndex)
        Actions.setFocus(collection: 'thread', item: item)
      if changeKeyboardCursor
        item = @_view.get(newFocusIndex)
        Actions.setCursorPosition(collection: 'thread', item: item)
        Actions.setFocus(collection: 'thread', item: item) if layoutMode is 'split'

    Actions.queueTask(task)
    @_view.selection.clear()

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

    index = Math.min(Math.max(index + offset, 0), @_view.count() - 2)
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

module.exports = new ThreadListStore()
