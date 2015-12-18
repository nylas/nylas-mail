React = require 'react'
classNames = require 'classnames'

MessageItem = require './message-item'

{Utils,
 DraftStore,
 MessageStore} = require 'nylas-exports'

{InjectedComponent} = require 'nylas-component-kit'

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
    @setState(@_getStateFromStores())

  componentDidMount: =>
    if @props.message?.draft
      @unlisten = DraftStore.listen @_onSendingStateChanged

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  componentWillUnmount: =>
    @unlisten() if @unlisten

  focus: => @refs.message.focus?()

  render: =>
    if @props.message.draft
      if @state.isSending
        @_renderMessage(pending: true)
      else
        @_renderComposer()
    else
      @_renderMessage(pending: false)

  _renderMessage: ({pending}) =>
    <MessageItem ref="message"
                 pending={pending}
                 thread={@props.thread}
                 message={@props.message}
                 className={@_classNames()}
                 collapsed={@props.collapsed}
                 isLastMsg={@props.isLastMsg} />

  _renderComposer: =>
    props =
      mode: "inline"
      draftClientId: @props.message.clientId
      threadId: @props.thread.id
      scrollTo: @props.scrollTo

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

  _onSendingStateChanged: (draftClientId) =>
    @setState(@_getStateFromStores()) if draftClientId is @props.message.clientId

  _getStateFromStores: ->
    isSending: DraftStore.isSendingDraft(@props.message.clientId)

module.exports = MessageItemContainer
