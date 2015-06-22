React = require 'react'
{Actions} = require 'nylas-exports'
{RetinaImg, ButtonDropdown} = require 'nylas-component-kit'

class MessageControls extends React.Component
  @displayName: "MessageControls"
  @propTypes:
    thread: React.PropTypes.object.isRequired
    message: React.PropTypes.object.isRequired

  constructor: (@props) ->

  render: =>
    <div className="message-actions-wrap">
      <div className="message-actions-ellipsis" onClick={@_onShowActionsMenu}>
        <RetinaImg name={"message-actions-ellipsis.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      </div>

      <ButtonDropdown
        primaryItem={@_primaryMessageAction()}
        secondaryItems={@_secondaryMessageActions()}/>
    </div>

  _primaryMessageAction: =>
    if @_replyType() is "reply"
      <span onClick={@_onReply}>
        <RetinaImg name="reply-footer.png" mode={RetinaImg.Mode.ContentIsMask}/>
      </span>
    else # if "reply-all"
      <span onClick={@_onReplyAll}>
        <RetinaImg name="reply-all-footer.png" mode={RetinaImg.Mode.ContentIsMask}/>
      </span>

  _secondaryMessageActions: ->
    if @_replyType() is "reply"
      return [@_replyAllAction(), @_forwardAction()]
    else #if "reply-all"
      return [@_replyAction(), @_forwardAction()]

  _forwardAction: ->
    <span onClick={@_onForward}>
      <RetinaImg name="forward-message-header.png" mode={RetinaImg.Mode.ContentIsMask}/>&nbsp;&nbsp;Forward
    </span>
  _replyAction: ->
    <span onClick={@_onReply}>
      <RetinaImg name="reply-footer.png" mode={RetinaImg.Mode.ContentIsMask}/>&nbsp;&nbsp;Reply
    </span>
  _replyAllAction: ->
    <span onClick={@_onReplyAll}>
      <RetinaImg name="reply-all-footer.png" mode={RetinaImg.Mode.ContentIsMask}/>&nbsp;&nbsp;Reply All
    </span>

  _onReply: =>
    Actions.composeReply(thread: @props.thread, message: @props.message)

  _onReplyAll: =>
    Actions.composeReplyAll(thread: @props.thread, message: @props.message)

  _onForward: =>
    Actions.composeForward(thread: @props.thread, message: @props.message)

  _replyType: =>
    if @props.message.cc.length is 0 and @props.message.to.length is 1
      return "reply"
    else return "reply-all"

module.exports = MessageControls

      # <InjectedComponentSet className="message-actions"
      #                       inline={true}
      #                       matching={role:"MessageAction"}
      #                       exposedProps={thread:@props.thread, message: @props.message}>
      #   <button className="btn btn-icon" onClick={@_onReply}>
      #     <RetinaImg name={"message-reply.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      #   </button>
      #   <button className="btn btn-icon" onClick={@_onReplyAll}>
      #     <RetinaImg name={"message-reply-all.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      #   </button>
      #   <button className="btn btn-icon" onClick={@_onForward}>
      #     <RetinaImg name={"message-forward.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      #   </button>
      # </InjectedComponentSet>
