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

ThreadListDataSource = require './thread-list-data-source'

# Public: A mutable text container with undo/redo support and the ability
# to annotate logical regions in the text.
class ThreadListStore extends NylasStore
  constructor: ->
    @listenTo FocusedPerspectiveStore, @_onPerspectiveChanged
    @createListDataSource()

  dataSource: =>
    @_dataSource

  createListDataSource: =>
    mailboxPerspective = FocusedPerspectiveStore.current()
    @_dataSource = new ThreadListDataSource(mailboxPerspective.threads())

    @_dataSourceUnlisten?()
    @_dataSourceUnlisten = @_dataSource.listen(@_onDataChanged, @)

    # Set up a one-time listener to focus an item in the new view
    if WorkspaceStore.layoutMode() is 'split'
      unlisten = @_dataSource.listen =>
        if @_dataSource.loaded()
          Actions.setFocus(collection: 'thread', item: @_dataSource.get(0))
          unlisten()

    @trigger(@)
    Actions.setFocus(collection: 'thread', item: null)

  # Inbound Events

  _onPerspectiveChanged: =>
    @createListDataSource()

  _onDataChanged: ({previous, next} = {}) =>
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
