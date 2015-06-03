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

class ThreadList extends React.Component
  @displayName: 'ThreadList'

  @containerRequired: false

  componentWillMount: =>
    labelComponents = (thread) =>
      for label in @state.threadLabelComponents
        LabelComponent = label.view
        <LabelComponent thread={thread} />

    lastMessageType = (thread) ->
      myEmail = NamespaceStore.current()?.emailAddress

      msgs = thread.metadata
      return 'unknown' unless msgs and msgs instanceof Array

      msgs = _.filter msgs, (m) -> m.isSaved() and not m.draft
      msg = msgs[msgs.length - 1]
      return 'unknown' unless msgs.length > 0

      if thread.unread
        return 'unread'
      else if msg.from[0]?.email isnt myEmail or msgs.length is 1
        return 'other'
      else if Utils.isForwardedMessage(msg)
        return 'forwarded'
      else
        return 'replied'

    c1 = new ListTabular.Column
      name: "★"
      resolver: (thread) =>
        <div className="thread-icon thread-icon-#{lastMessageType(thread)}"></div>

    c2 = new ListTabular.Column
      name: "Name"
      width: 200
      resolver: (thread) =>
        hasDraft = _.find (thread.metadata ? []), (m) -> m.draft
        if hasDraft
          <div style={display: 'flex'}>
            <ThreadListParticipants thread={thread} />
            <RetinaImg name="icon-draft-pencil.png" className="draft-icon" />
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
