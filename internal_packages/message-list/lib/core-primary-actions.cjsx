React = require 'react'
{Actions} = require("inbox-exports")

module.exports =
  ReplyButton: React.createClass
    render: ->
      <button className="reply-button btn-icon" onClick={@_onReply}><i className="fa fa-mail-reply"></i></button>

    _onReply: ->
      Actions.composeReply(@props.thread.id)

  ReplyAllButton: React.createClass
    render: ->
      <button className="reply-all-button btn-icon" onClick={@_onReplyAll}><i className="fa fa-mail-reply-all"></i></button>

    _onReplyAll: ->
      Actions.composeReplyAll(@props.thread.id)

  ForwardButton: React.createClass
    render: ->
      <button className="forward-button btn-icon" onClick={@_onForward}><i className="fa fa-mail-forward"></i></button>

    _onForward: ->
      Actions.composeForward(@props.thread.id)

  ArchiveButton: React.createClass
    render: ->
      <button className="archive-button btn-icon" onClick={@_onArchive}><i className="fa fa-archive"></i></button>

    _onArchive: ->
      # Calling archive() sends an Actions.queueTask with an archive task
      # TODO Turn into an Action
      @props.thread.archive()



