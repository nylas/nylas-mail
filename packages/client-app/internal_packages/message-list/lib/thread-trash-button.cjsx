_ = require 'underscore'
React = require 'react'
{Actions,
 DOMUtils,
 TaskFactory,
 AccountStore,
 FocusedPerspectiveStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class ThreadTrashButton extends React.Component
  @displayName: "ThreadTrashButton"
  @containerRequired: false

  @propTypes:
    thread: React.PropTypes.object.isRequired

  render: =>
    allowed = FocusedPerspectiveStore.current().canMoveThreadsTo([@props.thread], 'trash')
    return <span /> unless allowed

    <button className="btn btn-toolbar"
            style={order: -106}
            title="Move to Trash"
            onClick={@_onRemove}>
      <RetinaImg name="toolbar-trash.png" mode={RetinaImg.Mode.ContentIsMask}/>
    </button>

  _onRemove: (e) =>
    return unless DOMUtils.nodeIsVisible(e.currentTarget)
    Actions.trashThreads({
      source: "Toolbar Button: Thread List",
      threads: [@props.thread],
    })
    Actions.popSheet()
    e.stopPropagation()


module.exports = ThreadTrashButton
