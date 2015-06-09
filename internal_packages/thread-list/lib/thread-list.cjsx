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
ThreadListStore = require './thread-list-store'
ThreadListIcon = require './thread-list-icon'

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
    <div className="scroll-tooltip">
      {timestamp(@state.item?.lastMessageTimestamp)}
    </div>

class ThreadList extends React.Component
  @displayName: 'ThreadList'

  @containerRequired: false

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

    @columns = [c1, c2, c3, c4]
    @commands =
      'core:remove-item': @_onArchive
      'core:remove-and-previous': -> Actions.archiveAndPrevious()
      'core:remove-and-next': -> Actions.archiveAndNext()
      'application:reply': @_onReply
      'application:reply-all': @_onReplyAll
      'application:forward': @_onForward
    @itemPropsProvider = (item) ->
      className: classNames
        'unread': item.isUnread()

  render: =>
    <MultiselectList
      dataStore={ThreadListStore}
      columns={@columns}
      commands={@commands}
      itemPropsProvider={@itemPropsProvider}
      className="thread-list"
      scrollTooltipComponent={ThreadListScrollTooltip}
      collection="thread" />

  # Additional Commands

  _onArchive: =>
    if @_viewingFocusedThread() or ThreadListStore.view().selection.count() is 0
      Actions.archive()
    else
      Actions.archiveSelection()

  _onReply: ({focusedId}) =>
    return unless focusedId? and @_viewingFocusedThread()
    Actions.composeReply(threadId: focusedId)

  _onReplyAll: ({focusedId}) =>
    return unless focusedId? and @_viewingFocusedThread()
    Actions.composeReplyAll(threadId: focusedId)

  _onForward: ({focusedId}) =>
    return unless focusedId? and @_viewingFocusedThread()
    Actions.composeForward(threadId: focusedId)

  # Helpers

  _viewingFocusedThread: =>
    if WorkspaceStore.layoutMode() is "list"
      WorkspaceStore.topSheet() is WorkspaceStore.Sheet.Thread
    else
      true


module.exports = ThreadList
