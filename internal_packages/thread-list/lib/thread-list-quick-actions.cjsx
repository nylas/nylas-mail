React = require 'react'
{Actions,
 CategoryStore,
 TaskFactory,
 FocusedMailViewStore} = require 'nylas-exports'

class ThreadListQuickActions extends React.Component
  @displayName: 'ThreadListQuickActions'
  @propTypes:
    thread: React.PropTypes.object

  render: =>
    mailViewFilter = FocusedMailViewStore.mailView()
    archive = null
    remove = null

    if mailViewFilter?.canArchiveThreads()
      archive = <div key="archive"
                     title="Archive"
                     className="btn action action-archive"
                     onClick={@_onArchive}></div>

    if mailViewFilter?.canTrashThreads()
      trash = <div key="remove"
                   title="Trash"
                   className='btn action action-trash'
                   onClick={@_onRemove}></div>

    <div className="inner">
      {archive}
      {trash}
    </div>

  shouldComponentUpdate: (newProps, newState) ->
    newProps.thread.id isnt @props?.thread.id

  _onArchive: (event) =>
    task = TaskFactory.taskForArchiving
      threads: [@props.thread]
      fromView: FocusedMailViewStore.mailView()
    Actions.queueTask(task)

    # Don't trigger the thread row click
    event.stopPropagation()

  _onRemove: (event) =>
    task = TaskFactory.taskForMovingToTrash
      threads: [@props.thread]
      fromView: FocusedMailViewStore.mailView()
    Actions.queueTask(task)

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = ThreadListQuickActions
