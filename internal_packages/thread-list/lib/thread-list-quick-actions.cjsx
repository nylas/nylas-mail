React = require 'react'
{Actions,
 CategoryStore,
 TaskFactory,
 FocusedPerspectiveStore} = require 'nylas-exports'

class ThreadArchiveQuickAction extends React.Component
  @displayName: 'ThreadArchiveQuickAction'
  @propTypes:
    thread: React.PropTypes.object

  render: =>
    mailboxPerspective = FocusedPerspectiveStore.current()
    archive = null

    if mailboxPerspective?.canArchiveThreads()
      archive = <div key="archive"
                     title="Archive"
                     style={{ order: 100 }}
                     className="btn action action-archive"
                     onClick={@_onArchive}></div>
    return archive

  shouldComponentUpdate: (newProps, newState) ->
    newProps.thread.id isnt @props?.thread.id

  _onArchive: (event) =>
    tasks = TaskFactory.tasksForArchiving
      threads: [@props.thread]
      fromPerspective: FocusedPerspectiveStore.current()
    Actions.queueTasks(tasks)

    # Don't trigger the thread row click
    event.stopPropagation()

class ThreadTrashQuickAction extends React.Component
  @displayName: 'ThreadTrashQuickAction'
  @propTypes:
    thread: React.PropTypes.object

  render: =>
    mailboxPerspective = FocusedPerspectiveStore.current()
    trash = null

    if mailboxPerspective?.canTrashThreads()
      trash = <div key="remove"
                   title="Trash"
                   style={{ order: 110 }}
                   className='btn action action-trash'
                   onClick={@_onRemove}></div>
    return trash

  shouldComponentUpdate: (newProps, newState) ->
    newProps.thread.id isnt @props?.thread.id

  _onRemove: (event) =>
    tasks = TaskFactory.tasksForMovingToTrash
      threads: [@props.thread]
      fromPerspective: FocusedPerspectiveStore.current()
    Actions.queueTasks(tasks)

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = { ThreadArchiveQuickAction, ThreadTrashQuickAction }
