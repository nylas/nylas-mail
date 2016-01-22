_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'
{ListTabular,
 MultiselectList,
 RetinaImg,
 MailLabel,
 KeyCommandsRegion,
 InjectedComponentSet} = require 'nylas-component-kit'
{timestamp, subject} = require './formatting-utils'
{Actions,
 Utils,
 Thread,
 CanvasUtils,
 TaskFactory,
 ChangeUnreadTask,
 WorkspaceStore,
 AccountStore,
 CategoryStore,
 FocusedContentStore,
 FocusedMailViewStore} = require 'nylas-exports'
ThreadListParticipants = require './thread-list-participants'
{ThreadArchiveQuickAction,
 ThreadTrashQuickAction} = require './thread-list-quick-actions'
ThreadListStore = require './thread-list-store'
ThreadListIcon = require './thread-list-icon'

EmptyState = require './empty-state'
{MailImportantIcon} = require 'nylas-component-kit'

class ThreadListScrollTooltip extends React.Component
  @displayName: 'ThreadListScrollTooltip'
  @propTypes:
    viewportCenter: React.PropTypes.number.isRequired
    totalHeight: React.PropTypes.number.isRequired

  componentWillMount: =>
    @setupForProps(@props)

  componentWillReceiveProps: (newProps) =>
    @setupForProps(newProps)

  shouldComponentUpdate: (newProps, newState) =>
    @state?.idx isnt newState.idx

  setupForProps: (props) ->
    idx = Math.floor(ThreadListStore.view().count() / @props.totalHeight * @props.viewportCenter)
    @setState
      idx: idx
      item: ThreadListStore.view().get(idx)

  render: ->
    if @state.item
      content = timestamp(@state.item.lastMessageReceivedTimestamp)
    else
      content = "Loading..."
    <div className="scroll-tooltip">
      {content}
    </div>

class ThreadList extends React.Component
  @displayName: 'ThreadList'

  @containerRequired: false
  @containerStyles:
    minWidth: 300
    maxWidth: 3000

  constructor: (@props) ->
    @state =
      style: 'unknown'

  componentWillMount: =>
    c1 = new ListTabular.Column
      name: "★"
      resolver: (thread) =>
        [
          <ThreadListIcon key="thread-list-icon" thread={thread} />
          <MailImportantIcon key="mail-important-icon" thread={thread} />
          <InjectedComponentSet
            key="injected-component-set"
            inline={true}
            containersRequired={false}
            matching={role: "ThreadListIcon"}
            className="thread-injected-icons"
            exposedProps={thread: thread}/>
        ]

    c2 = new ListTabular.Column
      name: "Participants"
      width: 200
      resolver: (thread) =>
        hasDraft = _.find (thread.metadata ? []), (m) -> m.draft
        if hasDraft
          <div style={display: 'flex'}>
            <ThreadListParticipants thread={thread} />
            <RetinaImg name="icon-draft-pencil.png"
                       className="draft-icon"
                       mode={RetinaImg.Mode.ContentPreserve} />
          </div>
        else
          <ThreadListParticipants thread={thread} />

    c3LabelComponentCache = {}

    c3 = new ListTabular.Column
      name: "Message"
      flex: 4
      resolver: (thread) =>
        attachment = []
        labels = []
        if thread.hasAttachments
          attachment = <div className="thread-icon thread-icon-attachment"></div>

        currentCategoryId = FocusedMailViewStore.mailView()?.categoryId()

        ignoredIds = [currentCategoryId]
        ignoredIds.push(cat.id) for cat in CategoryStore.getHiddenCategories()

        for label in (thread.sortedLabels())
          continue if label.id in ignoredIds
          c3LabelComponentCache[label.id] ?= <MailLabel label={label} key={label.id} />
          labels.push c3LabelComponentCache[label.id]

        <span className="details">
          {labels}
          <span className="subject">{subject(thread.subject)}</span>
          <span className="snippet">{thread.snippet}</span>
          {attachment}
        </span>

    c4 = new ListTabular.Column
      name: "Date"
      resolver: (thread) =>
        <span className="timestamp">{timestamp(thread.lastMessageReceivedTimestamp)}</span>

    c5 = new ListTabular.Column
      name: "HoverActions"
      resolver: (thread) =>
        <div className="inner">
          <InjectedComponentSet
            key="injected-component-set"
            inline={true}
            containersRequired={false}
            children=
            {[
              <ThreadTrashQuickAction key="thread-trash-quick-action" thread={thread} />
              <ThreadArchiveQuickAction key="thread-arhive-quick-action" thread={thread} />
            ]}
            matching={role: "ThreadListQuickAction"}
            className="thread-injected-quick-actions"
            exposedProps={thread: thread}/>
        </div>

    @wideColumns = [c1, c2, c3, c4, c5]

    cNarrow = new ListTabular.Column
      name: "Item"
      flex: 1
      resolver: (thread) =>
        pencil = []
        attachment = []
        hasDraft = _.find (thread.metadata ? []), (m) -> m.draft
        if thread.hasAttachments
          attachment = <div className="thread-icon thread-icon-attachment"></div>
        if hasDraft
          pencil = <RetinaImg name="icon-draft-pencil.png" className="draft-icon" mode={RetinaImg.Mode.ContentPreserve} />

        <div>
          <div style={display: 'flex'}>
            <ThreadListIcon thread={thread} />
            <ThreadListParticipants thread={thread} />
            {pencil}
            <span style={flex:1}></span>
            {attachment}
            <span className="timestamp">{timestamp(thread.lastMessageReceivedTimestamp)}</span>
          </div>
          <MailImportantIcon thread={thread} />
          <div className="subject">{subject(thread.subject)}</div>
          <div className="snippet">{thread.snippet}</div>
        </div>

    @narrowColumns = [cNarrow]

    @itemPropsProvider = (item) ->
      className: classNames
        'unread': item.unread
      'data-thread-id': item.id

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
      @_shift(offset: -1, afterRunning: @_onRemoveFromView)
    'application:remove-and-next': =>
      @_shift(offset: 1, afterRunning: @_onRemoveFromView)

  render: ->
    <KeyCommandsRegion globalHandlers={@_keymapHandlers()}
                       className="thread-list-wrap">
      {@_renderList()}
    </KeyCommandsRegion>

  _renderList: =>
    if @state.style is 'wide'
      <MultiselectList
        dataStore={ThreadListStore}
        columns={@wideColumns}
        itemPropsProvider={@itemPropsProvider}
        itemHeight={39}
        className="thread-list"
        scrollTooltipComponent={ThreadListScrollTooltip}
        emptyComponent={EmptyState}
        onDragStart={@_onDragStart}
        onDragEnd={@_onDragEnd}
        draggable="true"
        collection="thread" />
    else if @state.style is 'narrow'
      <MultiselectList
        dataStore={ThreadListStore}
        columns={@narrowColumns}
        itemPropsProvider={@itemPropsProvider}
        itemHeight={90}
        className="thread-list thread-list-narrow"
        scrollTooltipComponent={ThreadListScrollTooltip}
        emptyComponent={EmptyState}
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
    return unless AccountStore.current()?.usesImportantFlag()
    category = CategoryStore.getStandardCategory('important')
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
        if FocusedMailViewStore.mailView().canTrashThreads()
          removeMethod = TaskFactory.taskForMovingToTrash
        else
          return
      else
        if FocusedMailViewStore.mailView().canArchiveThreads()
          removeMethod = TaskFactory.taskForArchiving
        else
          removeMethod = TaskFactory.taskForMovingToTrash

      task = removeMethod
        threads: threads
        fromView: FocusedMailViewStore.mailView()
      Actions.queueTask(task)

    Actions.popSheet()

  _onArchiveItem: =>
    return unless FocusedMailViewStore.mailView().canArchiveThreads()
    threads = @_threadsForKeyboardAction()
    if threads
      task = TaskFactory.taskForArchiving
        threads: threads
        fromView: FocusedMailViewStore.mailView()
      Actions.queueTask(task)
    Actions.popSheet()

  _onDeleteItem: =>
    return unless FocusedMailViewStore.mailView().canTrashThreads()
    threads = @_threadsForKeyboardAction()
    if threads
      task = TaskFactory.taskForMovingToTrash
        threads: threads
        fromView: FocusedMailViewStore.mailView()
      Actions.queueTask(task)
    Actions.popSheet()


module.exports = ThreadList
