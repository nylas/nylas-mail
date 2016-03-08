_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'

{MultiselectList, FluxContainer} = require 'nylas-component-kit'

{Actions,
 Thread,
 Category,
 CanvasUtils,
 TaskFactory,
 ChangeUnreadTask,
 ChangeStarredTask,
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
CategoryRemovalTargetRulesets = require './category-removal-target-rulesets'


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
    'application:remove-from-view': => @_onRemoveFromView
    'application:gmail-remove-from-view': =>
      @_onRemoveFromView(CategoryRemovalTargetRulesets.Gmail)
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

    props.shouldEnableSwipe = =>
      perspective = FocusedPerspectiveStore.current()
      tasks = perspective.tasksForRemovingItems([item], CategoryRemovalTargetRulesets.Default)
      return tasks.length > 0

    props.onSwipeRightClass = =>
      perspective = FocusedPerspectiveStore.current()
      tasks = perspective.tasksForRemovingItems([item], CategoryRemovalTargetRulesets.Default)
      return null if tasks.length is 0

      # TODO this logic is brittle
      task = tasks[0]
      name = if task instanceof ChangeStarredTask
        'unstar'
      else if task.categoriesToAdd().length is 1
        task.categoriesToAdd()[0].name
      else
        'remove'

      return "swipe-#{name}"

    props.onSwipeRight = (callback) ->
      perspective = FocusedPerspectiveStore.current()
      tasks = perspective.tasksForRemovingItems([item], CategoryRemovalTargetRulesets.Default)
      callback(false) if tasks.length is 0
      Actions.closePopover()
      Actions.queueTasks(tasks)
      callback(true)

    if FocusedPerspectiveStore.current().isInbox()
      props.onSwipeLeftClass = 'swipe-snooze'
      props.onSwipeCenter = =>
        Actions.closePopover()
      props.onSwipeLeft = (callback) =>
        # TODO this should be grabbed from elsewhere
        {PopoverStore} = require 'nylas-exports'
        SnoozePopoverBody = require '../../thread-snooze/lib/snooze-popover-body'

        element = document.querySelector("[data-item-id=\"#{item.id}\"]")
        rect = element.getBoundingClientRect()
        Actions.openPopover(
          <SnoozePopoverBody
            threads={[item]}
            swipeCallback={callback}
            closePopover={Actions.closePopover}/>,
          rect,
          "right"
        )

    return props

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
        categoriesToAdd: (accountId) ->
          [CategoryStore.getStandardCategory(accountId, 'important')]

    else
      tasks = TaskFactory.tasksForApplyingCategories
        threads: threads
        categoriesToRemove: (accountId) ->
          important = CategoryStore.getStandardCategory(accountId, 'important')
          return [important] if important
          return []

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

  _onRemoveFromView: (ruleset = CategoryRemovalTargetRulesets.Default) =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    current = FocusedPerspectiveStore.current()
    tasks = current.tasksForRemovingItems(threads, ruleset)
    Actions.queueTasks(tasks)
    Actions.popSheet()

  _onArchiveItem: =>
    threads = @_threadsForKeyboardAction()
    if threads
      tasks = TaskFactory.tasksForArchiving
        threads: threads
        fromPerspective: FocusedPerspectiveStore.current()
      Actions.queueTasks(tasks)
    Actions.popSheet()

  _onDeleteItem: =>
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
