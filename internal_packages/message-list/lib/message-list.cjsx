_ = require 'underscore-plus'
React = require 'react'
MessageItem = require "./message-item.cjsx"
{Actions, ThreadStore, MessageStore, ComponentRegistry} = require("inbox-exports")
{Spinner, ResizableRegion} = require('ui-components')

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
    if @state.messages.length > 0
      @_prepareContentForDisplay()

  componentWillUnmount: ->
    unsubscribe() for unsubscribe in @_unsubscribers

  shouldComponentUpdate: (nextProps, nextState) ->
    not _.isEqual(nextProps, @props) or not _.isEqual(nextState, @state)

  componentDidUpdate: (prevProps, prevState) ->
    didLoad = prevState.messages.length is 0 and @state.messages.length > 0

    oldDraftIds = _.map(_.filter((prevState.messages ? []), (m) -> m.draft), (m) -> m.id)
    newDraftIds = _.map(_.filter((@state.messages ? []), (m) -> m.draft), (m) -> m.id)
    addedDraftIds = _.difference(newDraftIds, oldDraftIds)
    didAddDraft = addedDraftIds.length > 0

    if didLoad
      @_prepareContentForDisplay()

    else if didAddDraft
      @_focusDraft(@refs["composerItem-#{addedDraftIds[0]}"])

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
      <div tabIndex="-1" className={wrapClass} ref="messageWrap">
        <div className="message-list-notification-bars">
          {@_messageListNotificationBars()}
        </div>

        {@_messageListHeaders()}
        {@_messageComponents()}
      </div>
      <Spinner visible={!@state.ready} />
    </div>

  # There may be a lot of iframes to load which may take an indeterminate
  # amount of time. As long as there is more content being painted onto
  # the page and our height is changing, keep waiting. Then scroll to message.
  scrollToMessage: (msgDOMNode, done) ->
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
        if stableCount is 5
          messageWrap.scrollTop = msgDOMNode.offsetTop
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
      initialFocus = not appliedInitialFocus and
                    ((message.draft) or
                     (message.unread) or
                     (idx is @state.messages.length - 1 and idx > 0))
      appliedInitialFocus ||= initialFocus

      className = React.addons.classSet
        "message-item-wrap": true
        "initial-focus": initialFocus
        "unread": message.unread
        "draft": message.draft

      if message.draft
        components.push <ComposerItem mode="inline"
                         ref="composerItem-#{message.id}"
                         key={@state.messageLocalIds[message.id]}
                         localId={@state.messageLocalIds[message.id]}
                         className={className} />
      else
        components.push <MessageItem key={message.id}
                         thread={@state.currentThread}
                         message={message}
                         className={className}
                         thread_participants={@_threadParticipants()} />

    components

  _onChange: ->
    @setState(@_getStateFromStores())

  _getStateFromStores: ->
    messages: (MessageStore.items() ? [])
    messageLocalIds: MessageStore.itemLocalIds()
    currentThread: ThreadStore.selectedThread()
    ready: if MessageStore.itemsLoading() then false else @state?.ready ? false

  _prepareContentForDisplay: ->
    _.delay =>
      return unless @isMounted()
      focusedMessage = @getDOMNode().querySelector(".initial-focus")
      @scrollToMessage focusedMessage, =>
        @setState(ready: true)
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

MessageList.minWidth = 680
MessageList.maxWidth = 900
