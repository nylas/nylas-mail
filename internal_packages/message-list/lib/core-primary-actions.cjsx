React = require 'react'
{Actions} = require("inbox-exports")

# Note: These always have a thread, but only sometimes get a
# message, depending on where in the UI they are being displayed.

module.exports =
  ReplyButton: React.createClass
    render: ->
      <button className="reply-button btn-icon" onClick={@_onReply}><i className="fa fa-mail-reply"></i></button>

    _onReply: (e) ->
      Actions.composeReply(threadId: @props.thread.id, messageId: @props.message?.id)
      e.stopPropagation()

  ReplyAllButton: React.createClass
    render: ->
      <button className="reply-all-button btn-icon" onClick={@_onReplyAll}><i className="fa fa-mail-reply-all"></i></button>

    _onReplyAll: (e) ->
      Actions.composeReplyAll(threadId: @props.thread.id, messageId: @props.message?.id)
      e.stopPropagation()

  ForwardButton: React.createClass
    render: ->
      <button className="forward-button btn-icon" onClick={@_onForward}><i className="fa fa-mail-forward"></i></button>

    _onForward: (e) ->
      Actions.composeForward(threadId: @props.thread.id, messageId: @props.message?.id)
      e.stopPropagation()

  ArchiveButton: React.createClass
    render: ->
      <button className="archive-button btn-icon" onClick={@_onArchive}><i className="fa fa-archive"></i></button>

    _onArchive: (e) ->
      # Calling archive() sends an Actions.queueTask with an archive task
      # TODO Turn into an Action
      @props.thread.archive()
      e.stopPropagation()
