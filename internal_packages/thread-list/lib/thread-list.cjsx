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
      itemHeight = 39
    else
      columns = ThreadListColumns.Narrow
      itemHeight = 90

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
    className: classNames
      'unread': item.unread

  _onDragStart: (event) =>
    itemThreadId = @refs.list.itemIdAtPoint(event.clientX, event.clientY)
    unless itemThreadId
      event.preventDefault()
      return

    dataSource = ThreadListStore.dataSource()
    if itemThreadId in dataSource.selection.ids()
      dragThreadIds = dataSource.selection.ids()
      dragAccountIds = _.uniq(_.pluck(dataSource.selection.items(), 'accountId'))
    else
      dragThreadIds = [itemThreadId]
      dragAccountIds = [dataSource.getById(itemThreadId).accountId]

    dragData = {
      accountIds: dragAccountIds,
      threadIds: dragThreadIds
    }

    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.dragEffect = "move"

    canvas = CanvasUtils.canvasWithThreadDragImage(dragThreadIds.length)
    event.dataTransfer.setDragImage(canvas, 10, 10)
    event.dataTransfer.setData('nylas-threads-data', JSON.stringify(dragData))
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

  _onSetUnread: (unread) =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    task = new ChangeUnreadTask
      threads: threads
      unread: unread
    Actions.queueTask(task)
    Actions.popSheet()

  _onMarkAsSpam: =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    tasks = TaskFactory.tasksForMarkingAsSpam(
      threads: threads
    )
    Actions.queueTasks(tasks)

  _onRemoveFromView: =>
    threads = @_threadsForKeyboardAction()
    if threads
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
