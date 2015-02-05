_ = require 'underscore-plus'
React = require 'react'
MessageItem = require "./message-item.cjsx"

ThreadParticipants = require "./thread-participants.cjsx"

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

  componentWillUnmount: ->
    unsubscribe() for unsubscribe in @_unsubscribers

  render: ->
    return <div></div> if not @state.current_thread?

    <div tabIndex=1 className="messages-wrap">
      <div className="message-list-primary-actions">
        {@_messageListPrimaryActions()}
      </div>

      <div className="message-list-notification-bars">
        {@_messageListNotificationBars()}
      </div>

      <div className="title-and-messages">
        {@_messageListHeaders()}

        <div className="message-components-wrap">
          {@_messageComponents()}
        </div>
      </div>
    </div>

  _messageListPrimaryActions: ->
    MLActions = ComponentRegistry.findAllViewsByRole('MessageListPrimaryAction')
    <div className="primary-actions-bar">
      {<MLAction thread={@state.current_thread} /> for MLAction in MLActions}
    </div>

  _messageListNotificationBars: ->
    MLBars = ComponentRegistry.findAllViewsByRole('MessageListNotificationBar')
    <div className="message-list-notification-bar-wrap">
      {<MLBar thread={@state.current_thread} /> for MLBar in MLBars}
    </div>

  _messageListHeaders: ->
    Participants = @state.Participants
    MessageListHeaders = ComponentRegistry.findAllViewsByRole('MessageListHeader')

    <div className="message-list-headers">
      <h2>{@state.current_thread.subject}</h2>

      {if Participants?
        <Participants clickable={true}
                      context={'primary'}
                      participants={@_threadParticipants()}/>
      else
        <ThreadParticipants thread_participants={@_threadParticipants()} />
      }

      {for MessageListHeader in MessageListHeaders
        <MessageListHeader thread={@state.current_thread} />
      }
    </div>

  _messageComponents: ->
    ComposerItem = @state.Composer
    containsUnread = _.any @state.messages, (m) -> m.unread
    collapsed = false
    components = []

    @state.messages?.forEach (message) =>
      if message.draft
        components.push <ComposerItem mode="inline"
                         key={@state.messageLocalIds[message.id]}
                         localId={@state.messageLocalIds[message.id]}
                         containerClass="message-item-wrap"/>
      else
        components.push <MessageItem key={message.id}
                         message={message}
                         collapsed={collapsed}
                         thread_participants={@_threadParticipants()} />

        # Start collapsing messages if we've loaded more than 15. This prevents
        # us from trying to load an unbounded number of iframes until we have
        # a better optimized message list.
        if components.length > 10
          collapsed = true

    components

  _onChange: ->
    @setState(@_getStateFromStores())

  _getStateFromStores: ->
    messages: (MessageStore.items() ? [])
    messageLocalIds: MessageStore.itemLocalIds()
    current_thread: ThreadStore.selectedThread()

  _threadParticipants: ->
    # We calculate the list of participants instead of grabbing it from
    # `@state.current_thread.participants` because it makes it easier to
    # test, is a better source of ground truth, and saves us from more
    # dependencies.
    participants = {}
    for msg in (@state.messages ? [])
      contacts = msg.participants()
      for contact in contacts
        if contact? and contact.email?.length > 0
          participants[contact.email] = contact
    return _.values(participants)
