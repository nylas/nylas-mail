React = require 'react'
{Actions, FocusedContentStore, ChangeUnreadTask} = require 'nylas-exports'
{RetinaImg, KeyCommandsRegion} = require 'nylas-component-kit'

class ThreadToggleUnreadButton extends React.Component
  @displayName: "ThreadToggleUnreadButton"
  @containerRequired: false

  render: =>
    fragment = if @props.thread?.unread then "read" else "unread"

    <KeyCommandsRegion globalHandlers={@_globalHandlers()} >
      <button className="btn btn-toolbar"
              style={order: -105}
              title="Mark as #{fragment}"
              onClick={@_onClick}>
        <RetinaImg name="toolbar-markas#{fragment}.png"
                   mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    </KeyCommandsRegion>

  _globalHandlers: =>
    'application:mark-as-unread': (e) => @_setUnread(e, true)
    'application:mark-as-read': (e) => @_setUnread(e, false)

  _onClick: (e) =>
    @_setUnread(e, !@props.thread.unread)

  _setUnread: (e, unread)=>
    task = new ChangeUnreadTask
      thread: @props.thread
      unread: unread
    Actions.queueTask(task)
    Actions.popSheet()
    e.stopPropagation()

module.exports = ThreadToggleUnreadButton
