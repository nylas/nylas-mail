React = require 'react'
classNames = require 'classnames'

MessageItem = require './message-item'
PendingMessageItem = require './pending-message-item'

{DraftStore,
 MessageStore} = require 'nylas-exports'

{InjectedComponent} = require 'nylas-component-kit'

class MessageItemContainer extends React.Component
  @displayName = 'MessageItemContainer'

  @propTypes =
    thread: React.PropTypes.object.isRequired
    message: React.PropTypes.object.isRequired

    # The localId (in the case of draft's local ID) is a derived
    # property that only the parent MessageList knows about.
    localId: React.PropTypes.string

    collapsed: React.PropTypes.bool
    isLastMsg: React.PropTypes.bool
    isBeforeReplyArea: React.PropTypes.bool
    onRequestScrollTo: React.PropTypes.func

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentWillReceiveProps: (newProps) ->
    @setState(@_getStateFromStores())

  componentDidMount: =>
    if @props.message?.draft
      @unlisten = DraftStore.listen @_onSendingStateChanged

  componentWillUnmount: =>
    @unlisten() if @unlisten

  focus: => @refs.message.focus?()

  render: =>
    if @props.message.draft
      if @state.isSending
        @_renderMessage(PendingMessageItem)
      else
        @_renderComposer()
    else
      @_renderMessage(MessageItem)

  _renderMessage: (component) =>
    <component ref="message"
               thread={@props.thread}
               message={@props.message}
               className={@_classNames()}
               collapsed={@props.collapsed}
               isLastMsg={@props.isLastMsg} />

  _renderComposer: =>
    props =
      mode: "inline"
      localId: @props.localId
      threadId: @props.thread.id
      onRequestScrollTo: @props.onRequestScrollTo

    <InjectedComponent ref="message"
                       matching={role: "Composer"}
                       className={@_classNames()}
                       exposedProps={props} />

  _classNames: => classNames
    "draft": @props.message.draft
    "unread": @props.message.unread
    "collapsed": @props.collapsed
    "message-item-wrap": true
    "before-reply-area": @props.isBeforeReplyArea

  _onSendingStateChanged: (draftLocalId) =>
    @setState(@_getStateFromStores()) if draftLocalId is @props.localId

  _getStateFromStores: ->
    isSending: DraftStore.isSendingDraft(@props.localId)

module.exports = MessageItemContainer
