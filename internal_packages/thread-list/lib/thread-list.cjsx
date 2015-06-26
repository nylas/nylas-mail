_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'
{ListTabular, MultiselectList, RetinaImg} = require 'nylas-component-kit'
{timestamp, subject} = require './formatting-utils'
{Actions,
 Utils,
 Thread,
 WorkspaceStore,
 NamespaceStore} = require 'nylas-exports'

ThreadListParticipants = require './thread-list-participants'
ThreadListQuickActions = require './thread-list-quick-actions'
ThreadListStore = require './thread-list-store'
ThreadListIcon = require './thread-list-icon'

EmptyState = require './empty-state'

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
      content = timestamp(@state.item.lastMessageTimestamp)
    else
      content = "Loading..."
    <div className="scroll-tooltip">
      {content}
    </div>

class ThreadList extends React.Component
  @displayName: 'ThreadList'

  @containerRequired: false

  constructor: (@props) ->
    @state =
      style: 'unknown'

  componentWillMount: =>
    labelComponents = (thread) =>
      for label in @state.threadLabelComponents
        LabelComponent = label.view
        <LabelComponent thread={thread} />

    c1 = new ListTabular.Column
      name: "★"
      resolver: (thread) =>
        <ThreadListIcon thread={thread} />

    c2 = new ListTabular.Column
      name: "Name"
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

    c3 = new ListTabular.Column
      name: "Message"
      flex: 4
      resolver: (thread) =>
        attachments = []
        if thread.hasTagId('attachment')
          attachments = <div className="thread-icon thread-icon-attachment"></div>
        <span className="details">
          <span className="subject">{subject(thread.subject)}</span>
          <span className="snippet">{thread.snippet}</span>
          {attachments}
        </span>

    c4 = new ListTabular.Column
      name: "Date"
      resolver: (thread) =>
        <span className="timestamp">{timestamp(thread.lastMessageTimestamp)}</span>

    c5 = new ListTabular.Column
      name: "HoverActions"
      resolver: (thread) =>
        <ThreadListQuickActions thread={thread}/>

    @wideColumns = [c1, c2, c3, c4, c5]

    cNarrow = new ListTabular.Column
      name: "Item"
      flex: 1
      resolver: (thread) =>
        pencil = []
        hasDraft = _.find (thread.metadata ? []), (m) -> m.draft
        if hasDraft
          pencil = <RetinaImg name="icon-draft-pencil.png" className="draft-icon" mode={RetinaImg.Mode.ContentPreserve} />

        <div>
          <div style={display: 'flex'}>
            <ThreadListIcon thread={thread} />
            <ThreadListParticipants thread={thread} />
            <span className="timestamp">{timestamp(thread.lastMessageTimestamp)}</span>
            {pencil}
          </div>
          <div className="subject">{subject(thread.subject)}</div>
          <div className="snippet">{thread.snippet}</div>
        </div>

    @narrowColumns = [cNarrow]

    @commands =
      'core:remove-item': @_onArchive
      'core:star-item': @_onStarItem
      'core:remove-and-previous': -> Actions.archiveAndPrevious()
      'core:remove-and-next': -> Actions.archiveAndNext()

    @itemPropsProvider = (item) ->
      className: classNames
        'unread': item.isUnread()

  componentDidMount: =>
    window.addEventListener('resize', @_onResize, true)
    @_onResize()

  componentWillUnmount: =>
    window.removeEventListener('resize', @_onResize)

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
        collection="thread" />
    else
      <div></div>

  _onResize: (event) =>
    current = @state.style
    desired = if React.findDOMNode(@).offsetWidth < 540 then 'narrow' else 'wide'
    if current isnt desired
      @setState(style: desired)

  # Additional Commands

  _onStarItem: =>
    if WorkspaceStore.layoutMode() is "list" and WorkspaceStore.topSheet() is WorkspaceStore.Sheet.Thread
      Actions.toggleStarFocused()
    else if ThreadListStore.view().selection.count() > 0
      Actions.toggleStarSelection()
    else
      Actions.toggleStarFocused()

  _onArchive: =>
    if WorkspaceStore.layoutMode() is "list" and WorkspaceStore.topSheet() is WorkspaceStore.Sheet.Thread
      Actions.archive()
    else if ThreadListStore.view().selection.count() > 0
      Actions.archiveSelection()
    else
      Actions.archive()


module.exports = ThreadList
