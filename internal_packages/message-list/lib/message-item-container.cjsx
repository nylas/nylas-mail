React = require 'react'
classNames = require 'classnames'

MessageItem = require './message-item'

{Utils,
 DraftStore,
 ComponentRegistry,
 MessageStore} = require 'nylas-exports'


class MessageItemContainer extends React.Component
  @displayName = 'MessageItemContainer'

  @propTypes =
    thread: React.PropTypes.object.isRequired
    message: React.PropTypes.object.isRequired
    collapsed: React.PropTypes.bool
    isLastMsg: React.PropTypes.bool
    isBeforeReplyArea: React.PropTypes.bool
    scrollTo: React.PropTypes.func

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentWillReceiveProps: (newProps) ->
    @setState(@_getStateFromStores(newProps))

  componentDidMount: =>
    if @props.message.draft
      @_unlisten = DraftStore.listen @_onSendingStateChanged

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  componentWillUnmount: =>
    @_unlisten() if @_unlisten

  focus: =>
    @refs.message.focus()

  render: =>
    if @props.message.draft
      if @state.isSending
        @_renderMessage(pending: true)
      else
        @_renderComposer()
    else
      @_renderMessage(pending: false)

  _renderMessage: ({pending}) =>
    <MessageItem
      ref="message"
      pending={pending}
      thread={@props.thread}
      message={@props.message}
      className={@_classNames()}
      collapsed={@props.collapsed}
      isLastMsg={@props.isLastMsg} />

  _renderComposer: =>
    Composer = ComponentRegistry.findComponentsMatching(role: 'Composer')[0]
    if (!Composer)
      return <span></span>

    <Composer
      ref="message"
      draftClientId={@props.message.clientId}
      className={@_classNames()}
      mode={"inline"}
      threadId={@props.thread.id}
      scrollTo={@props.scrollTo}
    />

  _classNames: => classNames
    "draft": @props.message.draft
    "unread": @props.message.unread
    "collapsed": @props.collapsed
    "message-item-wrap": true
    "before-reply-area": @props.isBeforeReplyArea

  _onSendingStateChanged: (draftClientId) =>
    if draftClientId is @props.message.clientId
      @setState(@_getStateFromStores())

  _getStateFromStores: (props = @props) ->
    isSending: DraftStore.isSendingDraft(props.message.clientId)

module.exports = MessageItemContainer
