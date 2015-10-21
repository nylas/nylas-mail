React = require 'react'
{Actions, FocusedContentStore, ChangeUnreadTask} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class ThreadToggleUnreadButton extends React.Component
  @displayName: "ThreadToggleUnreadButton"
  @containerRequired: false

  render: =>
    fragment = if @props.thread?.unread then "read" else "unread"

    <button className="btn btn-toolbar"
            style={order: -105}
            data-tooltip="Mark as #{fragment}"
            onClick={@_onClick}>
      <RetinaImg name="icon-toolbar-markas#{fragment}@2x.png"
      mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onClick: (e) =>
    task = new ChangeUnreadTask
      thread: @props.thread
      unread: !@props.thread.unread
    Actions.queueTask(task)
    Actions.popSheet()
    e.stopPropagation()

module.exports = ThreadToggleUnreadButton
