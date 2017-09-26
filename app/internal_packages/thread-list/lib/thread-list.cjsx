_ = require 'underscore'
React = require 'react'
ReactDOM = require 'react-dom'
classnames = require 'classnames'

{MultiselectList,
 FocusContainer,
 EmptyListState,
 FluxContainer
 SyncingListState} = require 'mailspring-component-kit'

{Actions,
 Utils,
 Thread,
 Category,
 CanvasUtils,
 TaskFactory,
 ChangeStarredTask,
 ChangeFolderTask,
 ChangeLabelsTask,
 WorkspaceStore,
 AccountStore,
 CategoryStore,
 ExtensionRegistry,
 FocusedContentStore,
 FocusedPerspectiveStore
 FolderSyncProgressStore} = require 'mailspring-exports'

ThreadListColumns = require './thread-list-columns'
ThreadListScrollTooltip = require './thread-list-scroll-tooltip'
ThreadListStore = require './thread-list-store'
ThreadListContextMenu = require('./thread-list-context-menu').default


class ThreadList extends React.Component
  @displayName: 'ThreadList'

  @containerRequired: false
  @containerStyles:
    minWidth: 300
    maxWidth: 3000

  constructor: (@props) ->
    @state =
      style: 'unknown'
      syncing: false

  componentDidMount: =>
    @unsub = FolderSyncProgressStore.listen( => @setState
      syncing: FocusedPerspectiveStore.current().hasSyncingCategories()
    )
    window.addEventListener('resize', @_onResize, true)
    ReactDOM.findDOMNode(@).addEventListener('contextmenu', @_onShowContextMenu)
    @_onResize()

  shouldComponentUpdate: (nextProps, nextState) =>
    return (
      (not Utils.isEqualReact(@props, nextProps)) or
      (not Utils.isEqualReact(@state, nextState))
    )

  componentWillUnmount: =>
    @unsub()
    window.removeEventListener('resize', @_onResize, true)
    ReactDOM.findDOMNode(@).removeEventListener('contextmenu', @_onShowContextMenu)

  _shift: ({offset, afterRunning}) =>
    dataSource = ThreadListStore.dataSource()
    focusedId = FocusedContentStore.focusedId('thread')
    focusedIdx = Math.min(dataSource.count() - 1, Math.max(0, dataSource.indexOfId(focusedId) + offset))
    item = dataSource.get(focusedIdx)
    afterRunning()
    Actions.setFocus(collection: 'thread', item: item)

  _keymapHandlers: ->
    'core:remove-from-view': =>
      @_onRemoveFromView()
    'core:gmail-remove-from-view': =>
      @_onRemoveFromView() # todo bg
    'core:archive-item': @_onArchiveItem
    'core:delete-item': @_onDeleteItem
    'core:star-item': @_onStarItem
    'core:snooze-item': @_onSnoozeItem
    'core:mark-important': => @_onSetImportant(true)
    'core:mark-unimportant': => @_onSetImportant(false)
    'core:mark-as-unread': => @_onSetUnread(true)
    'core:mark-as-read': => @_onSetUnread(false)
    'core:report-as-spam': => @_onMarkAsSpam(false)
    'core:remove-and-previous': =>
      @_shift(offset: -1, afterRunning: @_onRemoveFromView)
    'core:remove-and-next': =>
      @_shift(offset: 1, afterRunning: @_onRemoveFromView)
    'thread-list:select-read': @_onSelectRead
    'thread-list:select-unread': @_onSelectUnread
    'thread-list:select-starred': @_onSelectStarred
    'thread-list:select-unstarred': @_onSelectUnstarred

  _getFooter: ->
    return null unless @state.syncing
    return null if ThreadListStore.dataSource().count() <= 0
    return <SyncingListState />

  render: ->
    if @state.style is 'wide'
      columns = ThreadListColumns.Wide
      itemHeight = 36
    else
      columns = ThreadListColumns.Narrow
      itemHeight = 85

    <FluxContainer
      footer={@_getFooter()}
      stores=[ThreadListStore]
      getStateFromStores={ -> dataSource: ThreadListStore.dataSource() }>
      <FocusContainer collection="thread">
        <MultiselectList
          ref="list"
          draggable
          columns={columns}
          itemPropsProvider={@_threadPropsProvider}
          itemHeight={itemHeight}
          className="thread-list thread-list-#{@state.style}"
          scrollTooltipComponent={ThreadListScrollTooltip}
          EmptyComponent={EmptyListState}
          keymapHandlers={@_keymapHandlers()}
          onDoubleClick={(thread) -> Actions.popoutThread(thread)}
          onDragStart={@_onDragStart}
          onDragEnd={@_onDragEnd}
        />
      </FocusContainer>
    </FluxContainer>

  _threadPropsProvider: (item) ->
    classes = classnames({
      'unread': item.unread
    })
    classes += ExtensionRegistry.ThreadList.extensions()
    .filter((ext) => ext.cssClassNamesForThreadListItem?)
    .reduce(((prev, ext) => prev + ' ' + ext.cssClassNamesForThreadListItem(item)), ' ')

    props =
      className: classes

    props.shouldEnableSwipe = =>
      perspective = FocusedPerspectiveStore.current()
      tasks = perspective.tasksForRemovingItems([item], "Swipe")
      return tasks.length > 0

    props.onSwipeRightClass = =>
      perspective = FocusedPerspectiveStore.current()
      tasks = perspective.tasksForRemovingItems([item], "Swipe")
      return null if tasks.length is 0

      # TODO this logic is brittle
      task = tasks[0]
      name = if task instanceof ChangeStarredTask
        'unstar'
      else if task instanceof ChangeFolderTask
        task.folder.name
      else if task instanceof ChangeLabelsTask
        'archive'
      else
        'remove'

      return "swipe-#{name}"

    props.onSwipeRight = (callback) ->
      perspective = FocusedPerspectiveStore.current()
      tasks = perspective.tasksForRemovingItems([item], "Swipe")
      callback(false) if tasks.length is 0
      Actions.closePopover()
      Actions.queueTasks(tasks)
      callback(true)

    disabledPackages = AppEnv.config.get('core.disabledPackages') ? []
    if 'thread-snooze' in disabledPackages
      return props

    if FocusedPerspectiveStore.current().isInbox()
      props.onSwipeLeftClass = 'swipe-snooze'
      props.onSwipeCenter = =>
        Actions.closePopover()
      props.onSwipeLeft = (callback) =>
        # TODO this should be grabbed from elsewhere
        SnoozePopover = require('../../thread-snooze/lib/snooze-popover').default

        element = document.querySelector("[data-item-id=\"#{item.id}\"]")
        originRect = element.getBoundingClientRect()
        Actions.openPopover(
          <SnoozePopover
            threads={[item]}
            swipeCallback={callback} />,
          {originRect, direction: 'right', fallbackDirection: 'down'}
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

  _onSyncStatusChanged: =>
    syncing = FocusedPerspectiveStore.current().hasSyncingCategories()
    @setState({syncing})

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
    event.dataTransfer.setData("nylas-threads-data", JSON.stringify(data))
    event.dataTransfer.setData("nylas-accounts=#{data.accountIds.join(',')}", "1")
    return

  _onDragEnd: (event) =>

  _onResize: (event) =>
    current = @state.style
    desired = if ReactDOM.findDOMNode(@).offsetWidth < 540 then 'narrow' else 'wide'
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
    Actions.queueTask(TaskFactory.taskForInvertingStarred({
      threads, source: "Keyboard Shortcut",
    }))

  _onSnoozeItem: =>
    disabledPackages = AppEnv.config.get('core.disabledPackages') ? []
    if 'thread-snooze' in disabledPackages
      return

    threads = @_threadsForKeyboardAction()
    return unless threads
    # TODO this should be grabbed from elsewhere
    SnoozePopover = require('../../thread-snooze/lib/snooze-popover').default

    element = document.querySelector(".snooze-button.btn.btn-toolbar")
    return unless element
    originRect = element.getBoundingClientRect()
    Actions.openPopover(
      <SnoozePopover
        threads={threads} />,
      {originRect, direction: 'down'}
    )

  _onSetImportant: (important) =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    return unless AppEnv.config.get('core.workspace.showImportant')

    Actions.queueTasks(TaskFactory.tasksForThreadsByAccountId(threads, (accountThreads, accountId) => 
      return new ChangeLabelsTask({
        threads: accountThreads,
        source: "Keyboard Shortcut"
        labelsToAdd: if important then [CategoryStore.getCategoryByRole(accountId, 'important')] else []
        labelsToRemove: if important then [] else [CategoryStore.getCategoryByRole(accountId, 'important')]
      })
    ))

  _onSetUnread: (unread) =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    Actions.queueTask(TaskFactory.taskForInvertingUnread({threads, unread, source: "Keyboard Shortcut"}))
    Actions.popSheet()

  _onMarkAsSpam: =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    tasks = TaskFactory.tasksForMarkingAsSpam
      source: "Keyboard Shortcut"
      threads: threads
    Actions.queueTasks(tasks)

  _onRemoveFromView: (ruleset) =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    current = FocusedPerspectiveStore.current()
    tasks = current.tasksForRemovingItems(threads, "Keyboard Shortcut")
    Actions.queueTasks(tasks)
    Actions.popSheet()

  _onArchiveItem: =>
    threads = @_threadsForKeyboardAction()
    if threads
      tasks = TaskFactory.tasksForArchiving
        source: "Keyboard Shortcut"
        threads: threads
      Actions.queueTasks(tasks)
    Actions.popSheet()

  _onDeleteItem: =>
    threads = @_threadsForKeyboardAction()
    if threads
      tasks = TaskFactory.tasksForMovingToTrash
        source: "Keyboard Shortcut"
        threads: threads
      Actions.queueTasks(tasks)
    Actions.popSheet()

  _onSelectRead: =>
    dataSource = ThreadListStore.dataSource()
    items = dataSource.itemsCurrentlyInViewMatching (item) -> not item.unread
    @refs.list.handler().onSelect(items)

  _onSelectUnread: =>
    dataSource = ThreadListStore.dataSource()
    items = dataSource.itemsCurrentlyInViewMatching (item) -> item.unread
    @refs.list.handler().onSelect(items)

  _onSelectStarred: =>
    dataSource = ThreadListStore.dataSource()
    items = dataSource.itemsCurrentlyInViewMatching (item) -> item.starred
    @refs.list.handler().onSelect(items)

  _onSelectUnstarred: =>
    dataSource = ThreadListStore.dataSource()
    items = dataSource.itemsCurrentlyInViewMatching (item) -> not item.starred
    @refs.list.handler().onSelect(items)

module.exports = ThreadList
