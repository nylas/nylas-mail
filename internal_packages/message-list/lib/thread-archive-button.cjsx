{RetinaImg} = require 'nylas-component-kit'
{Actions,
 React,
 TaskFactory,
 DOMUtils,
 FocusedPerspectiveStore} = require 'nylas-exports'

class ThreadArchiveButton extends React.Component
  @displayName: "ThreadArchiveButton"
  @containerRequired: false

  @propTypes:
    thread: React.PropTypes.object.isRequired

  render: =>
    return false unless FocusedPerspectiveStore.current()?.canArchiveThreads()

    <button className="btn btn-toolbar btn-archive"
            style={order: -107}
            title="Archive"
            onClick={@_onArchive}>
      <RetinaImg name="toolbar-archive.png" mode={RetinaImg.Mode.ContentIsMask}/>
    </button>

  _onArchive: (e) =>
    return unless DOMUtils.nodeIsVisible(e.currentTarget)
    task = TaskFactory.taskForArchiving
      threads: [@props.thread],
      fromPerspective: FocusedPerspectiveStore.current()
    Actions.queueTask(task)
    Actions.popSheet()
    e.stopPropagation()

module.exports = ThreadArchiveButton
