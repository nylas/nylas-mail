_ = require 'underscore'
React = require 'react'
{Actions,
 DOMUtils,
 TaskFactory,
 FocusedPerspectiveStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class ThreadTrashButton extends React.Component
  @displayName: "ThreadTrashButton"
  @containerRequired: false

  @propTypes:
    thread: React.PropTypes.object.isRequired

  render: =>
    focusedMailboxPerspective = FocusedPerspectiveStore.current()
    return false unless focusedMailboxPerspective.canTrashThreads()

    <button className="btn btn-toolbar"
            style={order: -106}
            title="Move to Trash"
            onClick={@_onRemove}>
      <RetinaImg name="toolbar-trash.png" mode={RetinaImg.Mode.ContentIsMask}/>
    </button>

  _onRemove: (e) =>
    return unless DOMUtils.nodeIsVisible(e.currentTarget)
    tasks = TaskFactory.tasksForMovingToTrash
      threads: [@props.thread],
      fromPerspective: FocusedPerspectiveStore.current()
    Actions.queueTasks(tasks)
    Actions.popSheet()
    e.stopPropagation()


module.exports = ThreadTrashButton
