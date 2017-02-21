_ = require 'underscore'
React = require 'react'
ReactDOM = require 'react-dom'
classnames = require 'classnames'

{MultiselectList,
 FocusContainer,
 EmptyListState,
 FluxContainer
 SyncingListState} = require 'nylas-component-kit'

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
 ExtensionRegistry,
 FocusedContentStore,
 FocusedPerspectiveStore
 NylasSyncStatusStore} = require 'nylas-exports'

ThreadListColumns = require './thread-list-columns'
ThreadListScrollTooltip = require './thread-list-scroll-tooltip'
ThreadListStore = require './thread-list-store'
ThreadListContextMenu = require('./thread-list-context-menu').default
CategoryRemovalTargetRulesets = require('./category-removal-target-rulesets').default


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
    @unsub = NylasSyncStatusStore.listen( => @setState
      syncing: FocusedPerspectiveStore.current().hasSyncingCategories()
    )
    window.addEventListener('resize', @_onResize, true)
    ReactDOM.findDOMNode(@).addEventListener('contextmenu', @_onShowContextMenu)
    @_onResize()

  componentDidUpdate: =>
    dataSource = ThreadListStore.dataSource()
    threads = dataSource.itemsCurrentlyInView()
    Actions.threadListDidUpdate(threads)

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
      @_onRemoveFromView(CategoryRemovalTargetRulesets.Gmail)
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


    # TODO this swiping logic needs some serious cleanup
    props.shouldEnableSwipe = =>
      perspective = FocusedPerspectiveStore.current()
      tasks = perspective.tasksForRemovingItems([item], CategoryRemovalTargetRulesets.Default, "Swipe")
      return tasks.length > 0

    props.onSwipeRightClass = =>
      perspective = FocusedPerspectiveStore.current()
      tasks = perspective.tasksForRemovingItems([item], CategoryRemovalTargetRulesets.Default, "Swipe")
      return null if tasks.length is 0

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
      tasks = perspective.tasksForRemovingItems([item], CategoryRemovalTargetRulesets.Default, "Swipe")
      if tasks.length is 0
        callback(false)
        return
      Actions.removeThreadsFromView({threads: [item], source: 'Swipe', ruleset: CategoryRemovalTargetRulesets.Default})
      Actions.closePopover()
      callback(true)

    disabledPackages = NylasEnv.config.get('core.disabledPackages') ? []
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
    Actions.toggleStarredThreads({threads, source: "Keyboard Shortcut"})

  _onSnoozeItem: =>
    disabledPackages = NylasEnv.config.get('core.disabledPackages') ? []
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
    return unless NylasEnv.config.get('core.workspace.showImportant')

    if important
      tasks = TaskFactory.tasksForApplyingCategories
        source: "Keyboard Shortcut"
        threads: threads
        categoriesToRemove: (accountId) -> []
        categoriesToAdd: (accountId) ->
          [CategoryStore.getStandardCategory(accountId, 'important')]

    else
      tasks = TaskFactory.tasksForApplyingCategories
        source: "Keyboard Shortcut"
        threads: threads
        categoriesToRemove: (accountId) ->
          important = CategoryStore.getStandardCategory(accountId, 'important')
          return [important] if important
          return []

    Actions.queueTasks(tasks)

  _onSetUnread: (unread) =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    Actions.queueTask(new ChangeUnreadTask({threads, unread, source: "Keyboard Shortcut"}))
    Actions.popSheet()

  _onMarkAsSpam: =>
    threads = @_threadsForKeyboardAction()
    return unless threads
    Actions.markAsSpamThreads({
      source: "Keyboard Shortcut",
      threads: threads,
    })

  _onRemoveFromView: (ruleset = CategoryRemovalTargetRulesets.Default) =>
    threads = @_threadsForKeyboardAction()
    if not threads
      return
    Actions.removeThreadsFromView({threads, ruleset, source: "Keyboard Shortcut"})
    Actions.popSheet()

  _onArchiveItem: =>
    threads = @_threadsForKeyboardAction()
    if not threads
      return
    Actions.archiveThreads({threads, source: "Keyboard Shortcut"})
    Actions.popSheet()

  _onDeleteItem: =>
    threads = @_threadsForKeyboardAction()
    if threads
      Actions.trashThreads({
        source: "Keyboard Shortcut",
        threads: threads,
      })
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
