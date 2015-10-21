_ = require 'underscore'
React = require 'react'
{RetinaImg} = require 'nylas-component-kit'
{Actions,
 TaskFactory,
 DOMUtils,
 FocusedMailViewStore} = require 'nylas-exports'

class ThreadArchiveButton extends React.Component
  @displayName: "ThreadArchiveButton"
  @containerRequired: false

  @propTypes:
    thread: React.PropTypes.object.isRequired

  render: =>
    return false unless FocusedMailViewStore.mailView()?.canArchiveThreads()

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
      fromView: FocusedMailViewStore.mailView()
    Actions.queueTask(task)
    e.stopPropagation()


module.exports = ThreadArchiveButton
