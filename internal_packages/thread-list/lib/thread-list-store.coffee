_ = require 'underscore'
NylasStore = require 'nylas-store'

{Thread,
 Message,
 Actions,
 DatabaseStore,
 WorkspaceStore,
 FocusedContentStore,
 TaskQueueStatusStore,
 FocusedPerspectiveStore} = require 'nylas-exports'

ThreadListViewFactory = require './thread-list-view-factory'

# Public: A mutable text container with undo/redo support and the ability
# to annotate logical regions in the text.
class ThreadListStore extends NylasStore
  constructor: ->
    @_resetInstanceVars()

    @listenTo FocusedPerspectiveStore, @_onMailViewChanged
    @createView()

    NylasEnv.commands.add "body",
      'thread-list:select-read'     : @_onSelectRead
      'thread-list:select-unread'   : @_onSelectUnread
      'thread-list:select-starred'  : @_onSelectStarred
      'thread-list:select-unstarred': @_onSelectUnstarred

    # We can't create a @view on construction because the CategoryStore
    # has hot yet been populated from the database with the list of
    # categories and their corresponding ids. Once that is ready, the
    # CategoryStore will trigger, which will update the
    # FocusedPerspectiveStore, which will cause us to create a new
    # @view.

  _resetInstanceVars: ->
    @_lastQuery = null

  view: ->
    @_view

  createView: ->
    mailboxPerspective = FocusedPerspectiveStore.current()
    return unless mailboxPerspective

    @setView(ThreadListViewFactory.viewForMailView(mailboxPerspective))
    Actions.setFocus(collection: 'thread', item: null)

  setView: (view) ->
    @_viewUnlisten() if @_viewUnlisten
    @_view = view
    @_viewUnlisten = view.listen(@_onViewDataChanged, @)

    # Set up a one-time listener to focus an item in the new view
    if WorkspaceStore.layoutMode() is 'split'
      unlisten = view.listen ->
        if view.loaded()
          Actions.setFocus(collection: 'thread', item: view.get(0))
          unlisten()

    @trigger(@)

  _onSelectRead: =>
    items = @_view.itemsCurrentlyInViewMatching (item) -> not item.unread
    @_view.selection.set(items)

  _onSelectUnread: =>
    items = @_view.itemsCurrentlyInViewMatching (item) -> item.unread
    @_view.selection.set(items)

  _onSelectStarred: =>
    items = @_view.itemsCurrentlyInViewMatching (item) -> item.starred
    @_view.selection.set(items)

  _onSelectUnstarred: =>
    items = @_view.itemsCurrentlyInViewMatching (item) -> not item.starred
    @_view.selection.set(items)

  # Inbound Events

  _onMailViewChanged: ->
    @createView()

  _onViewDataChanged: ({previous, next} = {}) =>
    if previous and next
      focusedId = FocusedContentStore.focusedId('thread')
      keyboardId = FocusedContentStore.keyboardCursorId('thread')
      viewModeAutofocuses = WorkspaceStore.layoutMode() is 'split' or WorkspaceStore.topSheet().root is true

      focusedIndex = previous.offsetOfId(focusedId)
      keyboardIndex = previous.offsetOfId(keyboardId)

      shiftIndex = (i) =>
        if i > 0 and (next.modelAtOffset(i - 1)?.unread or i >= next.count())
          return i - 1
        else
          return i

      focusedLost = focusedIndex >= 0 and next.offsetOfId(focusedId) is -1
      keyboardLost = keyboardIndex >= 0 and next.offsetOfId(keyboardId) is -1

      if viewModeAutofocuses and focusedLost
        Actions.setFocus(collection: 'thread', item: next.modelAtOffset(shiftIndex(focusedIndex)))

      if keyboardLost
        Actions.setCursorPosition(collection: 'thread', item: next.modelAtOffset(shiftIndex(keyboardIndex)))

    @trigger(@)

module.exports = new ThreadListStore()
