_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'

{ListTabular,
 MultiselectList,
 KeyCommandsRegion} = require 'nylas-component-kit'

{Actions,
 Thread,
 CanvasUtils,
 TaskFactory,
 ChangeUnreadTask,
 WorkspaceStore,
 AccountStore,
 CategoryStore,
 FocusedContentStore,
 FocusedPerspectiveStore} = require 'nylas-exports'

ThreadListColumns = require './thread-list-columns'
ThreadListScrollTooltip = require './thread-list-scroll-tooltip'
ThreadListStore = require './thread-list-store'
EmptyState = require './empty-state'


class ThreadList extends React.Component
  @displayName: 'ThreadList'

  @containerRequired: false
  @containerStyles:
    minWidth: 300
    maxWidth: 3000

  constructor: (@props) ->
    @state =
      style: 'unknown'

  componentDidMount: =>
    window.addEventListener('resize', @_onResize, true)
    @_onResize()

  componentWillUnmount: =>
    window.removeEventListener('resize', @_onResize, true)

  _shift: ({offset, afterRunning}) =>
    view = ThreadListStore.view()
    focusedId = FocusedContentStore.focusedId('thread')
    focusedIdx = Math.min(view.count() - 1, Math.max(0, view.indexOfId(focusedId) + offset))
    item = view.get(focusedIdx)
    afterRunning()
    Actions.setFocus(collection: 'thread', item: item)

  _keymapHandlers: ->
    'core:remove-from-view': @_onRemoveFromView
    'application:archive-item': @_onArchiveItem
    'application:delete-item': @_onDeleteItem
    'application:star-item': @_onStarItem
    'application:mark-important': @_onMarkImportantItem
    'application:mark-unimportant': @_onMarkUnimportantItem
    'application:mark-as-unread': @_onMarkUnreadItem
    'application:mark-as-read': @_onMarkReadItem
    'application:remove-and-previous': =>
      @_shift(offset: 1, afterRunning: @_onRemoveFromView)
    'application:remove-and-next': =>
      @_shift(offset: -1, afterRunning: @_onRemoveFromView)
    'thread-list:select-read': @_onSelectRead
    'thread-list:select-unread': @_onSelectUnread
    'thread-list:select-starred': @_onSelectStarred
    'thread-list:select-unstarred': @_onSelectUnstarred

  render: ->
    if @state.style is 'wide'
      <MultiselectList
        dataStore={ThreadListStore}
        columns={ThreadListColumns.Wide}
        itemPropsProvider={@_threadPropsProvider}
        itemHeight={39}
        className="thread-list"
        scrollTooltipComponent={ThreadListScrollTooltip}
        emptyComponent={EmptyState}
        keymapHandlers={@_keymapHandlers()}
        onDragStart={@_onDragStart}
        onDragEnd={@_onDragEnd}
        draggable="true"
        collection="thread" />
    else if @state.style is 'narrow'
      <MultiselectList
        dataStore={ThreadListStore}
        columns={ThreadListColumns.Narrow}
        itemPropsProvider={@_threadPropsProvider}
        itemHeight={90}
        className="thread-list thread-list-narrow"
        scrollTooltipComponent={ThreadListScrollTooltip}
        emptyComponent={EmptyState}
        keymapHandlers={@_keymapHandlers()}
        onDragStart={@_onDragStart}
        onDragEnd={@_onDragEnd}
        draggable="true"
        collection="thread" />
    else
      <div></div>

  _threadIdAtPoint: (x, y) ->
    item = document.elementFromPoint(event.clientX, event.clientY).closest('.list-item')
    return null unless item
    return item.dataset.threadId

  _threadPropsProvider: (item) ->
    className: classNames
      'unread': item.unread
    'data-thread-id': item.id

  _onDragStart: (event) =>
    itemThreadId = @_threadIdAtPoint(event.clientX, event.clientY)
    unless itemThreadId
      event.preventDefault()
      return

    if itemThreadId in ThreadListStore.view().selection.ids()
      dragThreadIds = ThreadListStore.view().selection.ids()
    else
      dragThreadIds = [itemThreadId]

    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.dragEffect = "move"

    canvas = CanvasUtils.canvasWithThreadDragImage(dragThreadIds.length)
    event.dataTransfer.setDragImage(canvas, 10, 10)
    event.dataTransfer.setData('nylas-thread-ids', JSON.stringify(dragThreadIds))
    return

  _onDragEnd: (event) =>

  _onResize: (event) =>
    current = @state.style
    desired = if React.findDOMNode(@).offsetWidth < 540 then 'narrow' else 'wide'
    if current isnt desired
      @setState(style: desired)

  _threadsForKeyboardAction: ->
    return null unless ThreadListStore.view()
    focused = FocusedContentStore.focused('thread')
    if focused
      return [focused]
    else if ThreadListStore.view().selection.count() > 0
      return ThreadListStore.view().selection.items()
    else
      return null

  _onStarItem: =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    task = TaskFactory.taskForInvertingStarred({threads})
    Actions.queueTask(task)

  _onMarkImportantItem: =>
    @_setImportant(true)

  _onMarkUnimportantItem: =>
    @_setImportant(false)

  _setImportant: (important) =>
    threads = @_threadsForKeyboardAction()
    return unless threads

    # TODO Can not apply to threads across more than one account for now
    account = AccountStore.accountForItems(threads)
    return unless account?

    return unless account.usesImportantFlag()
    return unless NylasEnv.config.get('core.workspace.showImportant')
    category = CategoryStore.getStandardCategory(account, 'important')
    if important
      task = TaskFactory.taskForApplyingCategory({threads, category})
    else
      task = TaskFactory.taskForRemovingCategory({threads, category})

    Actions.queueTask(task)

  _onMarkReadItem: =>
    @_setUnread(false)

  _onMarkUnreadItem: =>
    @_setUnread(true)

  _setUnread: (unread) =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    task = new ChangeUnreadTask
      threads: threads
      unread: unread
    Actions.queueTask(task)
    Actions.popSheet()

  _onRemoveFromView: =>
    threads = @_threadsForKeyboardAction()
    backspaceDelete = NylasEnv.config.get('core.reading.backspaceDelete')
    if threads
      if backspaceDelete
        if FocusedPerspectiveStore.current().canTrashThreads()
          removeMethod = TaskFactory.taskForMovingToTrash
        else
          return
      else
        if FocusedPerspectiveStore.current().canArchiveThreads()
          removeMethod = TaskFactory.taskForArchiving
        else
          removeMethod = TaskFactory.taskForMovingToTrash

      task = removeMethod
        threads: threads
        fromView: FocusedPerspectiveStore.current()
      Actions.queueTask(task)

    Actions.popSheet()

  _onArchiveItem: =>
    return unless FocusedPerspectiveStore.current().canArchiveThreads()
    threads = @_threadsForKeyboardAction()
    if threads
      task = TaskFactory.taskForArchiving
        threads: threads
        fromView: FocusedPerspectiveStore.current()
      Actions.queueTask(task)
    Actions.popSheet()

  _onDeleteItem: =>
    return unless FocusedPerspectiveStore.current().canTrashThreads()
    threads = @_threadsForKeyboardAction()
    if threads
      task = TaskFactory.taskForMovingToTrash
        threads: threads
        fromView: FocusedPerspectiveStore.current()
      Actions.queueTask(task)
    Actions.popSheet()

  _onSelectRead: =>
    view = ThreadListStore.view()
    items = view.itemsCurrentlyInViewMatching (item) -> not item.unread
    view.selection.set(items)

  _onSelectUnread: =>
    view = ThreadListStore.view()
    items = view.itemsCurrentlyInViewMatching (item) -> item.unread
    view.selection.set(items)

  _onSelectStarred: =>
    view = ThreadListStore.view()
    items = view.itemsCurrentlyInViewMatching (item) -> item.starred
    view.selection.set(items)

  _onSelectUnstarred: =>
    view = ThreadListStore.view()
    items = view.itemsCurrentlyInViewMatching (item) -> not item.starred
    view.selection.set(items)

module.exports = ThreadList
