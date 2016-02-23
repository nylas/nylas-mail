_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'

{MultiselectList, FluxContainer} = require 'nylas-component-kit'

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
FocusContainer = require './focus-container'
EmptyState = require './empty-state'
ThreadListContextMenu = require './thread-list-context-menu'


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
    React.findDOMNode(@).addEventListener('contextmenu', @_onShowContextMenu)
    @_onResize()

  componentWillUnmount: =>
    window.removeEventListener('resize', @_onResize, true)
    React.findDOMNode(@).removeEventListener('contextmenu', @_onShowContextMenu)

  _shift: ({offset, afterRunning}) =>
    dataSource = ThreadListStore.dataSource()
    focusedId = FocusedContentStore.focusedId('thread')
    focusedIdx = Math.min(dataSource.count() - 1, Math.max(0, dataSource.indexOfId(focusedId) + offset))
    item = dataSource.get(focusedIdx)
    afterRunning()
    Actions.setFocus(collection: 'thread', item: item)

  _keymapHandlers: ->
    'core:remove-from-view': @_onRemoveFromView
    'application:archive-item': @_onArchiveItem
    'application:delete-item': @_onDeleteItem
    'application:star-item': @_onStarItem
    'application:mark-important': => @_onSetImportant(true)
    'application:mark-unimportant': => @_onSetImportant(false)
    'application:mark-as-unread': => @_onSetUnread(true)
    'application:mark-as-read': => @_onSetUnread(false)
    'application:report-as-spam': => @_onMarkAsSpam(false)
    'application:remove-and-previous': =>
      @_shift(offset: -1, afterRunning: @_onRemoveFromView)
    'application:remove-and-next': =>
      @_shift(offset: 1, afterRunning: @_onRemoveFromView)
    'thread-list:select-read': @_onSelectRead
    'thread-list:select-unread': @_onSelectUnread
    'thread-list:select-starred': @_onSelectStarred
    'thread-list:select-unstarred': @_onSelectUnstarred

  render: ->
    if @state.style is 'wide'
      columns = ThreadListColumns.Wide
      itemHeight = 36
    else
      columns = ThreadListColumns.Narrow
      itemHeight = 85

    <FluxContainer
      stores=[ThreadListStore]
      getStateFromStores={ -> dataSource: ThreadListStore.dataSource() }>
      <FocusContainer collection="thread">
        <MultiselectList
          ref="list"
          columns={columns}
          itemPropsProvider={@_threadPropsProvider}
          itemHeight={itemHeight}
          className="thread-list thread-list-#{@state.style}"
          scrollTooltipComponent={ThreadListScrollTooltip}
          emptyComponent={EmptyState}
          keymapHandlers={@_keymapHandlers()}
          onDragStart={@_onDragStart}
          onDragEnd={@_onDragEnd}
          draggable="true" />
      </FocusContainer>
    </FluxContainer>

  _threadPropsProvider: (item) ->
    props =
      className: classNames
        'unread': item.unread

    perspective = FocusedPerspectiveStore.current()
    account = AccountStore.accountForId(item.accountId)
    finishedName = account.defaultFinishedCategory()?.name

    if finishedName is 'trash' and perspective.canTrashThreads()
      props.onSwipeRightClass = 'swipe-trash'
      props.onSwipeRight = (callback) ->
        tasks = TaskFactory.tasksForMovingToTrash
          threads: [item]
          fromPerspective: FocusedPerspectiveStore.current()
        Actions.queueTasks(tasks)
        callback(true)

    else if finishedName in ['archive', 'all'] and perspective.canArchiveThreads()
      props.onSwipeRightClass = 'swipe-archive'
      props.onSwipeRight = (callback) ->
        tasks = TaskFactory.tasksForArchiving
          threads: [item]
          fromPerspective: FocusedPerspectiveStore.current()
        Actions.queueTasks(tasks)
        callback(true)

    props

  _targetItemsForMouseEvent: (event) ->
    itemThreadId = @refs.list.itemIdAtPoint(event.clientX, event.clientY)
    unless itemThreadId
      return null

    dataSource = ThreadListStore.dataSource()
    if itemThreadId in dataSource.selection.ids()
      return {
        threadIds: dataSource.selection.ids()
        accountIds: _.uniq(_.pluck(dataSource.selection.items(), 'accountId'))
      }
    else
      thread = dataSource.getById(itemThreadId)
      return null unless thread
      return {
        threadIds: [thread.id]
        accountIds: [thread.accountId]
      }

  _onShowContextMenu: (event) =>
    data = @_targetItemsForMouseEvent(event)
    if not data
      event.preventDefault()
      return
    (new ThreadListContextMenu(data)).displayMenu()

  _onDragStart: (event) =>
    data = @_targetItemsForMouseEvent(event)
    if not data
      event.preventDefault()
      return

    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.dragEffect = "move"

    canvas = CanvasUtils.canvasWithThreadDragImage(data.threadIds.length)
    event.dataTransfer.setDragImage(canvas, 10, 10)
    event.dataTransfer.setData('nylas-threads-data', JSON.stringify(data))
    return

  _onDragEnd: (event) =>

  _onResize: (event) =>
    current = @state.style
    desired = if React.findDOMNode(@).offsetWidth < 540 then 'narrow' else 'wide'
    if current isnt desired
      @setState(style: desired)

  _threadsForKeyboardAction: ->
    return null unless ThreadListStore.dataSource()
    focused = FocusedContentStore.focused('thread')
    if focused
      return [focused]
    else if ThreadListStore.dataSource().selection.count() > 0
      return ThreadListStore.dataSource().selection.items()
    else
      return null

  _onStarItem: =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    task = TaskFactory.taskForInvertingStarred({threads})
    Actions.queueTask(task)

  _onSetImportant: (important) =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    return unless NylasEnv.config.get('core.workspace.showImportant')

    if important
      tasks = TaskFactory.tasksForApplyingCategories
        threads: threads
        categoriesToRemove: (accountId) -> []
        categoryToAdd: (accountId) ->
          CategoryStore.getStandardCategory(accountId, 'important')

    else
      tasks = TaskFactory.tasksForApplyingCategories
        threads: threads
        categoriesToRemove: (accountId) ->
          important = CategoryStore.getStandardCategory(accountId, 'important')
          return [important] if important
          return []
        categoryToAdd: (accountId) -> null

    Actions.queueTasks(tasks)

  _onSetUnread: (unread) =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    Actions.queueTask(new ChangeUnreadTask({threads, unread}))
    Actions.popSheet()

  _onMarkAsSpam: =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    tasks = TaskFactory.tasksForMarkingAsSpam
      threads: threads
      fromPerspective: FocusedPerspectiveStore.current()
    Actions.queueTasks(tasks)

  _onRemoveFromView: =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    current = FocusedPerspectiveStore.current()
    current.removeThreads(threads)
    Actions.popSheet()

  _onArchiveItem: =>
    return unless FocusedPerspectiveStore.current().canArchiveThreads()
    threads = @_threadsForKeyboardAction()
    if threads
      tasks = TaskFactory.tasksForArchiving
        threads: threads
        fromPerspective: FocusedPerspectiveStore.current()
      Actions.queueTasks(tasks)
    Actions.popSheet()

  _onDeleteItem: =>
    return unless FocusedPerspectiveStore.current().canTrashThreads()
    threads = @_threadsForKeyboardAction()
    if threads
      tasks = TaskFactory.tasksForMovingToTrash
        threads: threads
        fromPerspective: FocusedPerspectiveStore.current()
      Actions.queueTasks(tasks)
    Actions.popSheet()

  _onSelectRead: =>
    dataSource = ThreadListStore.dataSource()
    items = dataSource.itemsCurrentlyInViewMatching (item) -> not item.unread
    dataSource.selection.set(items)

  _onSelectUnread: =>
    dataSource = ThreadListStore.dataSource()
    items = dataSource.itemsCurrentlyInViewMatching (item) -> item.unread
    dataSource.selection.set(items)

  _onSelectStarred: =>
    dataSource = ThreadListStore.dataSource()
    items = dataSource.itemsCurrentlyInViewMatching (item) -> item.starred
    dataSource.selection.set(items)

  _onSelectUnstarred: =>
    dataSource = ThreadListStore.dataSource()
    items = dataSource.itemsCurrentlyInViewMatching (item) -> not item.starred
    dataSource.selection.set(items)

module.exports = ThreadList
