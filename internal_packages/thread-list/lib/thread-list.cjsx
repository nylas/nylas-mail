_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'
{ListTabular,
 MultiselectList,
 RetinaImg,
 MailLabel,
 InjectedComponentSet} = require 'nylas-component-kit'
{timestamp, subject} = require './formatting-utils'
{Actions,
 Utils,
 Thread,
 CanvasUtils,
 TaskFactory,
 WorkspaceStore,
 AccountStore,
 CategoryStore,
 FocusedContentStore,
 FocusedMailViewStore} = require 'nylas-exports'

ThreadListParticipants = require './thread-list-participants'
ThreadListQuickActions = require './thread-list-quick-actions'
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
          <ThreadListIcon thread={thread} />
          <MailImportantIcon thread={thread} />
          <InjectedComponentSet
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
        allCategoryId = CategoryStore.getStandardCategory('all')?.id

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
        <ThreadListQuickActions thread={thread} />

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

    _shift = ({offset, afterRunning}) =>
      view = ThreadListStore.view()
      focusedId = FocusedContentStore.focusedId('thread')
      focusedIdx = Math.min(view.count() - 1, Math.max(0, view.indexOfId(focusedId) + offset))
      item = view.get(focusedIdx)
      afterRunning()
      Actions.setFocus(collection: 'thread', item: item)

    @commands =
      'core:remove-item': @_onBackspace
      'core:star-item': @_onStarItem
      'core:remove-and-previous': =>
        _shift(offset: 1, afterRunning: @_onBackspace)
      'core:remove-and-next': =>
        _shift(offset: -1, afterRunning: @_onBackspace)

    @itemPropsProvider = (item) ->
      className: classNames
        'unread': item.unread
      'data-thread-id': item.id

  componentDidMount: =>
    window.addEventListener('resize', @_onResize, true)
    @_onResize()

  componentWillUnmount: =>
    window.removeEventListener('resize', @_onResize, true)

  render: =>
    if @state.style is 'wide'
      <MultiselectList
        dataStore={ThreadListStore}
        columns={@wideColumns}
        commands={@commands}
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
        commands={@commands}
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

  # Additional Commands

  _onStarItem: =>
    return unless ThreadListStore.view()

    focused = FocusedContentStore.focused('thread')
      
    if WorkspaceStore.layoutMode() is "list" and WorkspaceStore.topSheet() is WorkspaceStore.Sheet.Thread
      threads = [focused]
    else if ThreadListStore.view().selection.count() > 0
      threads = ThreadListStore.view().selection.items()
    else
      threads = [focused]

    task = TaskFactory.taskForInvertingStarred({threads})
    Actions.queueTask(task)

  _onBackspace: =>
    return unless ThreadListStore.view()

    focused = FocusedContentStore.focused('thread')

    if WorkspaceStore.layoutMode() is "split" and focused
      task = TaskFactory.taskForMovingToTrash
        threads: [focused]
        fromView: FocusedMailViewStore.mailView()
      Actions.queueTask(task)

    else if ThreadListStore.view().selection.count() > 0
      task = TaskFactory.taskForMovingToTrash
        threads: ThreadListStore.view().selection.items()
        fromView: FocusedMailViewStore.mailView()
      Actions.queueTask(task)

    else if WorkspaceStore.layoutMode() is "list" and WorkspaceStore.topSheet() is WorkspaceStore.Sheet.Thread
      Actions.popSheet()


module.exports = ThreadList
