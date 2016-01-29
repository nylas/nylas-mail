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
{ListTabular} = require 'nylas-component-kit'

ThreadListDataSource = require './thread-list-data-source'

class ThreadListStore extends NylasStore
  constructor: ->
    @listenTo FocusedPerspectiveStore, @_onPerspectiveChanged
    @createListDataSource()

  dataSource: =>
    @_dataSource

  createListDataSource: =>
    @_dataSourceUnlisten?()
    @_dataSource = null

    threadsSubscription = FocusedPerspectiveStore.current().threads()
    if threadsSubscription
      @_dataSource = new ThreadListDataSource(threadsSubscription)
      @_dataSourceUnlisten = @_dataSource.listen(@_onDataChanged, @)

      # Set up a one-time listener to focus an item in the new view
      if WorkspaceStore.layoutMode() is 'split'
        unlisten = @_dataSource.listen =>
          if @_dataSource.loaded()
            Actions.setFocus(collection: 'thread', item: @_dataSource.get(0))
            unlisten()
    else
      @_dataSource = new ListTabular.DataSource.Empty()

    @trigger(@)
    Actions.setFocus(collection: 'thread', item: null)

  # Inbound Events

  _onPerspectiveChanged: =>
    @createListDataSource()

  _onDataChanged: ({previous, next} = {}) =>
    # This code keeps the focus and keyboard cursor in sync with the thread list.
    # When the thread list changes, it looks to see if the focused thread is gone,
    # or no longer matches the query criteria and advances the focus to the next
    # thread.

    # This means that removing a thread from view in any way causes selection
    # to advance to the adjacent thread. Nice and declarative.

    if previous and next
      focused = FocusedContentStore.focused('thread')
      keyboard = FocusedContentStore.keyboardCursor('thread')
      viewModeAutofocuses = WorkspaceStore.layoutMode() is 'split' or WorkspaceStore.topSheet().root is true
      matchers = next.query()?.matchers()

      focusedIndex = if focused then previous.offsetOfId(focused.id) else -1
      keyboardIndex = if keyboard then previous.offsetOfId(keyboard.id) else -1

      nextItemFromIndex = (i) =>
        if i > 0 and (next.modelAtOffset(i - 1)?.unread or i >= next.count())
          nextIndex = i - 1
        else
          nextIndex = i

        # May return null if no thread is loaded at the next index
        next.modelAtOffset(nextIndex)

      notInSet = (model) ->
        if matchers
          return model.matches(matchers) is false
        else
          return next.offsetOfId(model.id) is -1

      if viewModeAutofocuses and focused and notInSet(focused)
        Actions.setFocus(collection: 'thread', item: nextItemFromIndex(focusedIndex))

      if keyboard and notInSet(keyboard)
        Actions.setCursorPosition(collection: 'thread', item: nextItemFromIndex(keyboardIndex))

    @trigger(@)

module.exports = new ThreadListStore()
