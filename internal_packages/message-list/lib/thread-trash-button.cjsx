_ = require 'underscore'
React = require 'react'
{Actions,
 DOMUtils,
 TaskFactory,
 FocusedMailViewStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class ThreadTrashButton extends React.Component
  @displayName: "ThreadTrashButton"
  @containerRequired: false

  @propTypes:
    thread: React.PropTypes.object.isRequired

  render: =>
    focusedMailViewFilter = FocusedMailViewStore.mailView()
    return false unless focusedMailViewFilter?.canTrashThreads()

    <button className="btn btn-toolbar"
            style={order: -106}
            data-tooltip="Move to Trash"
            onClick={@_onRemove}>
      <RetinaImg name="toolbar-trash.png" mode={RetinaImg.Mode.ContentIsMask}/>
    </button>

  _onRemove: (e) =>
    return unless DOMUtils.nodeIsVisible(e.currentTarget)
    task = TaskFactory.taskForMovingToTrash
      threads: [@props.thread],
      fromView: FocusedMailViewStore.mailView()
    Actions.queueTask(task)
    e.stopPropagation()


module.exports = ThreadTrashButton
