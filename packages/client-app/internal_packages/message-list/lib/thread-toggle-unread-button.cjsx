{Actions, React, FocusedContentStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class ThreadToggleUnreadButton extends React.Component
  @displayName: "ThreadToggleUnreadButton"
  @containerRequired: false

  render: =>
    fragment = if @props.thread?.unread then "read" else "unread"
    <button className="btn btn-toolbar"
            style={order: -105}
            title="Mark as #{fragment}"
            onClick={@_onClick}>
      <RetinaImg name="toolbar-markas#{fragment}.png"
                 mode={RetinaImg.Mode.ContentIsMask} />
    </button>

  _onClick: (e) =>
    Actions.toggleUnreadThreads({
      source: "Toolbar Button: Thread List",
      threads: [@props.thread],
    })
    Actions.popSheet()
    e.stopPropagation()

module.exports = ThreadToggleUnreadButton
