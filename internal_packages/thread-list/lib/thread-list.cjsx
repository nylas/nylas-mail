_ = require 'underscore-plus'
React = require 'react'
{ListTabular, Spinner} = require 'ui-components'
{timestamp, subject} = require './formatting-utils'
{Actions,
 Utils,
 Thread,
 WorkspaceStore,
 FocusedThreadStore,
 NamespaceStore} = require 'inbox-exports'

ThreadStore = require './thread-store'
ThreadListParticipants = require './thread-list-participants'

module.exports =
ThreadList = React.createClass
  displayName: 'ThreadList'

  getInitialState: ->
    @_getStateFromStores()
 
  componentWillMount: ->
    @_prepareColumns()

  componentDidMount: ->
    @thread_store_unsubscribe = ThreadStore.listen @_onChange
    @focus_store_unsubscribe = FocusedThreadStore.listen @_onChange
    @body_unsubscriber = atom.commands.add 'body', {
      'application:previous-item': => @_onShiftFocus(-1)
      'application:next-item': => @_onShiftFocus(1)
      'application:focus-item': => @_onFocus()
      'application:remove-item': -> Actions.archiveCurrentThread()
      'application:remove-and-previous': -> Actions.archiveAndPrevious()
      'application:remove-and-next': -> Actions.archiveAndNext()
      'application:reply': @_onReply
      'application:reply-all': @_onReplyAll
      'application:forward': @_onForward
    }

  componentWillUnmount: ->
    @focus_store_unsubscribe()
    @thread_store_unsubscribe()
    @body_unsubscriber.dispose()

  render: ->
    # IMPORTANT: DO NOT pass inline functions as props. _.isEqual thinks these
    # are "different", and will re-render everything. Instead, declare them with ?=,
    # pass a reference. (Alternatively, ignore these in children's shouldComponentUpdate.)
    #
    # BAD:   onSelect={ (item) -> Actions.focusThread(item) }
    # GOOD:  onSelect={@_onSelectItem}
    #
    classes = React.addons.classSet("thread-list": true, "ready": @state.ready)

    @_itemClassProvider ?= (item) -> if item.isUnread() then 'unread' else ''
    @_itemOnSelect ?= (item) -> Actions.focusThread(item)

    if @state.dataView
      <div className={classes}>
        <ListTabular
          columns={@_columns}
          dataView={@state.dataView}
          itemClassProvider={@_itemClassProvider}
          selectedId={@state.focusedId}
          onSelect={@_itemOnSelect} />
        <Spinner visible={!@state.ready} />
      </div>
    else
      <div className={classes}>
        <Spinner visible={!@state.ready} />
      </div>

  _prepareColumns: ->
    labelComponents = (thread) =>
      for label in @state.threadLabelComponents
        LabelComponent = label.view
        <LabelComponent thread={thread} />

    lastMessageType = (thread) ->
      myEmail = NamespaceStore.current()?.emailAddress
      msgs = thread.metadata
      return 'unknown' unless msgs and msgs instanceof Array and msgs.length > 0
      msg = msgs[msgs.length - 1]
      if thread.unread
        return 'unread'
      else if msg.from[0].email isnt myEmail
        return 'other'
      else if Utils.isForwardedMessage(msg)
        return 'forwarded'
      else
        return 'replied'

    c1 = new ListTabular.Column
      name: "★"
      resolver: (thread) ->
        <div className="thread-icon thread-icon-#{lastMessageType(thread)}"></div>

    c2 = new ListTabular.Column
      name: "Name"
      width: 200
      resolver: (thread) ->
        <ThreadListParticipants thread={thread} />

    c3 = new ListTabular.Column
      name: "Message"
      flex: 4
      resolver: (thread) ->
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
      resolver: (thread) ->
        <span className="timestamp">{timestamp(thread.lastMessageTimestamp)}</span>

    @_columns = [c1, c2, c3, c4]

  _onFocus: ->
    item = @state.dataView.getById(@state.focusedId)
    Actions.focusThread(item) if item

  _onShiftFocus: (delta) ->
    index = @state.dataView.indexOfId(@state.focusedId)
    index = Math.max(0, Math.min(index + delta, @state.dataView.count() - 1))
    Actions.focusThread(@state.dataView.get(index))

  _onReply: ->
    return unless @state.focusedId? and @_actionInVisualScope()
    Actions.composeReply(threadId: @state.focusedId)

  _onReplyAll: ->
    return unless @state.focusedId? and @_actionInVisualScope()
    Actions.composeReplyAll(threadId: @state.focusedId)

  _onForward: ->
    return unless @state.focusedId? and @_actionInVisualScope()
    Actions.composeForward(threadId: @state.focusedId)

  _actionInVisualScope: ->
    if WorkspaceStore.selectedLayoutMode() is "list"
      WorkspaceStore.sheet().type is "Thread"
    else
      true

  # Message list rendering is more important than thread list rendering.
  # Since they're on the same event listner, and the event listeners are
  # unordered, we need a way to push thread list updates later back in the
  # queue.
  _onChange: -> _.delay =>
    return unless @isMounted()
    @setState(@_getStateFromStores())
  , 30

  _getStateFromStores: ->
    dataView: ThreadStore.view()
    ready: ThreadStore.view()?.loaded()
    focusedId: FocusedThreadStore.threadId()
