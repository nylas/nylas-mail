React = require 'react'
{Actions,
 CategoryStore,
 TaskFactory,
 AccountStore,
 FocusedPerspectiveStore} = require 'nylas-exports'

class ThreadArchiveQuickAction extends React.Component
  @displayName: 'ThreadArchiveQuickAction'
  @propTypes:
    thread: React.PropTypes.object

  render: =>
    allowed = FocusedPerspectiveStore.current().canArchiveThreads([@props.thread])
    return <span /> unless allowed

    <div
      key="archive"
      title="Archive"
      style={{ order: 100 }}
      className="btn action action-archive"
      onClick={@_onArchive} />

  shouldComponentUpdate: (newProps, newState) ->
    newProps.thread.id isnt @props?.thread.id

  _onArchive: =>
    Actions.archiveThreads({
      source: "Quick Actions: Thread List",
      threads: [@props.thread],
    })

    # Don't trigger the thread row click
    event.stopPropagation()

class ThreadTrashQuickAction extends React.Component
  @displayName: 'ThreadTrashQuickAction'
  @propTypes:
    thread: React.PropTypes.object

  render: =>
    allowed = FocusedPerspectiveStore.current().canMoveThreadsTo([@props.thread], 'trash')
    return <span /> unless allowed

    <div
      key="remove"
      title="Trash"
      style={{ order: 110 }}
      className='btn action action-trash'
      onClick={@_onRemove} />

  shouldComponentUpdate: (newProps, newState) ->
    newProps.thread.id isnt @props?.thread.id

  _onRemove: (event) =>
    tasks = TaskFactory.tasksForMovingToTrash
      source: "Quick Actions: Thread List"
      threads: [@props.thread]
    Actions.queueTasks(tasks)

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = { ThreadArchiveQuickAction, ThreadTrashQuickAction }
