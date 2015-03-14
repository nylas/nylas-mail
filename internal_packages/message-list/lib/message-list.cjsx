_ = require 'underscore-plus'
React = require 'react'
MessageItem = require "./message-item.cjsx"
{Actions, ThreadStore, MessageStore, ComponentRegistry} = require("inbox-exports")

module.exports =
MessageList = React.createClass
  mixins: [ComponentRegistry.Mixin]
  components: ['Participants', 'Composer']
  displayName: 'MessageList'

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @_unsubscribers = []
    @_unsubscribers.push MessageStore.listen @_onChange
    @_unsubscribers.push ThreadStore.listen @_onChange
    @_lastHeight = -1
    @_scrollToBottom()

  componentWillUnmount: ->
    unsubscribe() for unsubscribe in @_unsubscribers

  componentWillUpdate: (nextProps, nextState) ->
    newDraftIds = @_newDraftIds(nextState)
    if newDraftIds.length >= 1
      @_focusComposerId = newDraftIds[0]

  componentDidUpdate: (prevProps, prevState) ->
    if @_shouldScroll(prevState)
      @_lastHeight = -1
      @_scrollToBottom()
      if @_focusComposerId?
        @_focusRef(@refs["composerItem-#{@_focusComposerId}"])
        @_focusComposerId = null

  # Only scroll if the messages change and there are some message
  _shouldScroll: (prevState) ->
    return false if (@state.messages ? []).length is 0
    prevMsg = (prevState.messages ? []).map((m) -> m.id)
    curMsg = (@state.messages ? []).map((m) -> m.id)
    return true if prevMsg.length isnt curMsg.length
    iLength = _.intersection(prevMsg, curMsg).length
    return true if iLength isnt prevMsg.length or iLength isnt curMsg.length
    return false


  # We need a 100ms delay so the DOM can finish painting the elements on
  # the page. The focus doesn't work for some reason while the paint is in
  # process.
  _focusRef: (component) -> _.delay ->
    if component?.isForwardedMessage()
      component?.focus("textFieldTo")
    else
      component?.focus("contentBody")
  , 100

  render: ->
    return <div></div> if not @state.currentThread?

    <div className="message-list" id="message-list">
      <div tabIndex=1 ref="messageWrap" className="messages-wrap">
        <div className="message-list-notification-bars">
          {@_messageListNotificationBars()}
        </div>

        {@_messageListHeaders()}
        {@_messageComponents()}
      </div>
    </div>

  _messageListNotificationBars: ->
    MLBars = ComponentRegistry.findAllViewsByRole('MessageListNotificationBar')
    <div className="message-list-notification-bar-wrap">
      {<MLBar thread={@state.currentThread} /> for MLBar in MLBars}
    </div>

  _messageListHeaders: ->
    Participants = @state.Participants
    MessageListHeaders = ComponentRegistry.findAllViewsByRole('MessageListHeader')

    <div className="message-list-headers">
      <h2 className="message-subject">{@state.currentThread.subject}</h2>

      {for MessageListHeader in MessageListHeaders
        <MessageListHeader thread={@state.currentThread} />
      }
    </div>

  _newDraftIds: (nextState) ->
    currentMsgIds = _.map(_.filter((@state.messages ? []), (m) -> not m.draft), (m) -> m.id)
    nextMsgIds = _.map(_.filter((nextState.messages ? []), (m) -> not m.draft), (m) -> m.id)

    # Only return if all the non-draft messages are the same. If the
    # non-draft messages aren't the same, that means we switched threads.
    # Don't focus on new drafts if we just switched threads.
    if nextMsgIds.length > 0 and _.difference(nextMsgIds, currentMsgIds).length is 0
      nextDraftIds = _.map(_.filter((nextState.messages ? []), (m) -> m.draft), (m) -> m.id)
      currentDraftIds = _.map(_.filter((@state.messages ? []), (m) -> m.draft), (m) -> m.id)
      return (_.difference(nextDraftIds, currentDraftIds) ? [])
    else return []

  _messageComponents: ->
    ComposerItem = @state.Composer
    # containsUnread = _.any @state.messages, (m) -> m.unread
    collapsed = false
    components = []

    @state.messages?.forEach (message) =>
      if message.draft
        components.push <ComposerItem mode="inline"
                         ref="composerItem-#{message.id}"
                         key={@state.messageLocalIds[message.id]}
                         localId={@state.messageLocalIds[message.id]}
                         containerClass="message-item-wrap draft-message"/>
      else
        className = "message-item-wrap"
        if message.unread then className += " unread-message"
        components.push <MessageItem key={message.id}
                         thread={@state.currentThread}
                         message={message}
                         collapsed={collapsed}
                         className={className}
                         thread_participants={@_threadParticipants()} />

    components

  _onChange: ->
    @setState(@_getStateFromStores())

  _getStateFromStores: ->
    messages: (MessageStore.items() ? [])
    messageLocalIds: MessageStore.itemLocalIds()
    currentThread: ThreadStore.selectedThread()

  _threadParticipants: ->
    # We calculate the list of participants instead of grabbing it from
    # `@state.currentThread.participants` because it makes it easier to
    # test, is a better source of ground truth, and saves us from more
    # dependencies.
    participants = {}
    for msg in (@state.messages ? [])
      contacts = msg.participants()
      for contact in contacts
        if contact? and contact.email?.length > 0
          participants[contact.email] = contact
    return _.values(participants)

  # There may be a lot of iframes to load which may take an indeterminate
  # amount of time. As long as there is more content being painted onto
  # the page, we keep trying to scroll to the bottom. We scroll to the top
  # of the last message.
  #
  # We don't scroll if there's only 1 item.
  # We don't scroll if you're actively focused somewhere in the message
  # list.
  _scrollToBottom: ->
    _.defer =>
      if @isMounted()
        messageWrap = @refs?.messageWrap?.getDOMNode?()

        return if not messageWrap?
        items = messageWrap.querySelectorAll(".message-item-wrap")
        return if items.length <= 1
        return if @getDOMNode().contains document.activeElement

        msgToScroll = messageWrap.querySelector(".draft-message, .unread-message")
        if not msgToScroll?
          msgToScroll = messageWrap.children[messageWrap.children.length - 1]

        currentHeight = messageWrap.getBoundingClientRect().height

        if currentHeight isnt @_lastHeight
          @_lastHeight = currentHeight
          @_scrollToBottom()
        else
          scrollTo = currentHeight - msgToScroll.getBoundingClientRect().height
          @getDOMNode().scrollTop = scrollTo

MessageList.minWidth = 680
MessageList.maxWidth = 900
