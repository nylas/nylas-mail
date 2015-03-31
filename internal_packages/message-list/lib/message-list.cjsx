_ = require 'underscore-plus'
React = require 'react'
MessageItem = require "./message-item"
{Utils, Actions, ThreadStore, MessageStore, ComponentRegistry} = require("inbox-exports")
{Spinner, ResizableRegion, RetinaImg} = require('ui-components')

module.exports =
MessageList = React.createClass
  mixins: [ComponentRegistry.Mixin]
  components: ['Participants', 'Composer']
  displayName: 'MessageList'

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @__onResize = _.bind @_onResize, @
    window.addEventListener("resize", @__onResize)
    @_unsubscribers = []
    @_unsubscribers.push MessageStore.listen @_onChange
    # We don't need to listen to ThreadStore bcause MessageStore already
    # listens to thead selection changes

    if not MessageStore.itemsLoading()
      @_prepareContentForDisplay()

  componentWillUnmount: ->
    unsubscribe() for unsubscribe in @_unsubscribers
    window.removeEventListener("resize", @__onResize)

  shouldComponentUpdate: (nextProps, nextState) ->
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  componentDidUpdate: (prevProps, prevState) ->
    newDraftIds = @_newDraftIds(prevState)
    newMessageIds = @_newMessageIds(prevState)

    if newDraftIds.length > 0
      @_focusDraft(@refs["composerItem-#{newDraftIds[0]}"])
      @_prepareContentForDisplay()
    else if newMessageIds.length > 0
      @_prepareContentForDisplay()

  _newDraftIds: (prevState) ->
    oldDraftIds = _.map(_.filter((prevState.messages ? []), (m) -> m.draft), (m) -> m.id)
    newDraftIds = _.map(_.filter((@state.messages ? []), (m) -> m.draft), (m) -> m.id)
    return _.difference(newDraftIds, oldDraftIds) ? []

  _newMessageIds: (prevState) ->
    oldMessageIds = _.map(_.reject((prevState.messages ? []), (m) -> m.draft), (m) -> m.id)
    newMessageIds = _.map(_.reject((@state.messages ? []), (m) -> m.draft), (m) -> m.id)
    return _.difference(newMessageIds, oldMessageIds) ? []

  _focusDraft: (draftDOMNode) ->
    # We need a 100ms delay so the DOM can finish painting the elements on
    # the page. The focus doesn't work for some reason while the paint is in
    # process.
    _.delay =>
      return unless @isMounted
      draftDOMNode.focus()
    ,100

  render: ->
    return <div></div> if not @state.currentThread?

    wrapClass = React.addons.classSet
      "messages-wrap": true
      "ready": @state.ready

    <div className="message-list" id="message-list">
      <div tabIndex="-1"
           className={wrapClass}
           onScroll={_.debounce(@_cacheScrollPos, 100)}
           ref="messageWrap">
        <div className="message-list-notification-bars">
          {@_messageListNotificationBars()}
        </div>

        {@_messageListHeaders()}
        {@_messageComponents()}
      </div>
      {@_renderReplyArea()}
      <Spinner visible={!@state.ready} />
    </div>

  _renderReplyArea: ->
    if @_hasReplyArea()
      <div className="footer-reply-area-wrap" onClick={@_onClickReplyArea}>
        <div className="footer-reply-area">
          <RetinaImg name="#{@_replyType()}-footer.png" /><span className="reply-text">Write a reply…</span>
        </div>
      </div>
    else return <div></div>

  _hasReplyArea: ->
    not _.last(@state.messages)?.draft

  # Either returns "reply" or "reply-all"
  _replyType: ->
    lastMsg = _.last(_.filter((@state.messages ? []), (m) -> not m.draft))
    if lastMsg?.cc.length is 0 and lastMsg?.to.length is 1
      return "reply"
    else return "reply-all"

  _onClickReplyArea: ->
    return unless @state.currentThread?.id
    if @_replyType() is "reply-all"
      Actions.composeReplyAll(threadId: @state.currentThread.id)
    else
      Actions.composeReply(threadId: @state.currentThread.id)

  # There may be a lot of iframes to load which may take an indeterminate
  # amount of time. As long as there is more content being painted onto
  # the page and our height is changing, keep waiting. Then scroll to message.
  scrollToMessage: (msgDOMNode, done, location="top", stability=5) ->
    return done() unless msgDOMNode?

    messageWrap = @refs.messageWrap?.getDOMNode()
    lastHeight = -1
    stableCount = 0
    scrollIfSettled = =>
      return unless @isMounted()

      messageWrapHeight = messageWrap.getBoundingClientRect().height
      if messageWrapHeight isnt lastHeight
        lastHeight = messageWrapHeight
        stableCount = 0
      else
        stableCount += 1
        if stableCount is stability
          if location is "top"
            messageWrap.scrollTop = msgDOMNode.offsetTop
          else if location is "bottom"
            offsetTop = msgDOMNode.offsetTop
            messageHeight = msgDOMNode.getBoundingClientRect().height
            messageWrap.scrollTop = offsetTop - (messageWrapHeight - messageHeight)
          return done()

      window.requestAnimationFrame -> scrollIfSettled(msgDOMNode, done)
  
    scrollIfSettled()

  _messageListNotificationBars: ->
    MLBars = ComponentRegistry.findAllViewsByRole('MessageListNotificationBar')
    <div className="message-list-notification-bar-wrap">
      {<MLBar thread={@state.currentThread} /> for MLBar in MLBars}
    </div>

  _messageListHeaders: ->
    Participants = @state.Participants
    MessageListHeaders = ComponentRegistry.findAllViewsByRole('MessageListHeader')

    <div className="message-list-headers">
      {for MessageListHeader in MessageListHeaders
        <MessageListHeader thread={@state.currentThread} />
      }
    </div>

  _messageComponents: ->
    ComposerItem = @state.Composer
    appliedInitialFocus = false
    components = []

    @state.messages?.forEach (message, idx) =>
      collapsed = !@state.messagesExpandedState[message.id]

      initialFocus = not appliedInitialFocus and not collapsed and
                    ((message.draft) or
                     (message.unread) or
                     (idx is @state.messages.length - 1 and idx > 0))
      appliedInitialFocus ||= initialFocus

      className = React.addons.classSet
        "message-item-wrap": true
        "initial-focus": initialFocus
        "unread": message.unread
        "draft": message.draft
        "collapsed": collapsed

      if message.draft
        components.push <ComposerItem mode="inline"
                         ref="composerItem-#{message.id}"
                         key={@state.messageLocalIds[message.id]}
                         localId={@state.messageLocalIds[message.id]}
                         onRequestScrollTo={@_onRequestScrollToComposer}
                         className={className} />
      else
        components.push <MessageItem key={message.id}
                         thread={@state.currentThread}
                         message={message}
                         className={className}
                         collapsed={collapsed}
                         thread_participants={@_threadParticipants()} />

      if idx < @state.messages.length - 1
        next = @state.messages[idx + 1]
        nextCollapsed = next and !@state.messagesExpandedState[next.id]
        if collapsed and nextCollapsed
          components.push <hr className="message-item-divider collapsed" />
        else
          components.push <hr className="message-item-divider" />

    components

  # Some child components (like the compser) might request that we scroll
  # to the bottom of the component.
  _onRequestScrollToComposer: ({messageId, location}={}) ->
    return unless @isMounted()
    done = ->
    location ?= "bottom"
    composer = @refs["composerItem-#{messageId}"]?.getDOMNode()
    @scrollToMessage(composer, done, location, 1)

  _onChange: ->
    @setState(@_getStateFromStores())

  _getStateFromStores: ->
    messages: (MessageStore.items() ? [])
    messageLocalIds: MessageStore.itemLocalIds()
    messagesExpandedState: MessageStore.itemsExpandedState()
    currentThread: ThreadStore.selectedThread()
    ready: if MessageStore.itemsLoading() then false else @state?.ready ? false

  _prepareContentForDisplay: ->
    _.delay =>
      return unless @isMounted()
      focusedMessage = @getDOMNode().querySelector(".initial-focus")
      @scrollToMessage focusedMessage, =>
        @setState(ready: true)
      @_cacheScrollPos()
    , 100

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

  _onResize: (event) ->
    return unless @isMounted()
    @_scrollToBottom() if @_wasAtBottom()
    @_cacheScrollPos()

  _scrollToBottom: ->
    messageWrap = @refs.messageWrap?.getDOMNode()
    messageWrap.scrollTop = messageWrap.scrollHeight

  _cacheScrollPos: ->
    messageWrap = @refs.messageWrap?.getDOMNode()
    return unless messageWrap
    @_lastScrollTop = messageWrap.scrollTop
    @_lastHeight = messageWrap.getBoundingClientRect().height
    @_lastScrollHeight = messageWrap.scrollHeight

  _wasAtBottom: ->
    (@_lastScrollTop + @_lastHeight) >= @_lastScrollHeight

MessageList.minWidth = 500
MessageList.maxWidth = 900
