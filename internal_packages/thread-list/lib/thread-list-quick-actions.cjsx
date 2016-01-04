React = require 'react'
{Actions,
 CategoryStore,
 TaskFactory,
 FocusedMailViewStore} = require 'nylas-exports'

class ThreadArchiveQuickAction extends React.Component
  @displayName: 'ThreadArchiveQuickAction'
  @propTypes:
    thread: React.PropTypes.object

  render: =>
    mailViewFilter = FocusedMailViewStore.mailView()
    archive = null

    if mailViewFilter?.canArchiveThreads()
      archive = <div key="archive"
                     title="Archive"
                     style={{ order: 110 }}
                     className="btn action action-archive"
                     onClick={@_onArchive}></div>
    return archive

  shouldComponentUpdate: (newProps, newState) ->
    newProps.thread.id isnt @props?.thread.id

  _onArchive: (event) =>
    task = TaskFactory.taskForArchiving
      threads: [@props.thread]
      fromView: FocusedMailViewStore.mailView()
    Actions.queueTask(task)

    # Don't trigger the thread row click
    event.stopPropagation()

class ThreadTrashQuickAction extends React.Component
  @displayName: 'ThreadTrashQuickAction'
  @propTypes:
    thread: React.PropTypes.object

  render: =>
    mailViewFilter = FocusedMailViewStore.mailView()
    trash = null

    if mailViewFilter?.canTrashThreads()
      trash = <div key="remove"
                   title="Trash"
                   style={{ order: 100 }}
                   className='btn action action-trash'
                   onClick={@_onRemove}></div>
    return trash

  shouldComponentUpdate: (newProps, newState) ->
    newProps.thread.id isnt @props?.thread.id

  _onRemove: (event) =>
    task = TaskFactory.taskForMovingToTrash
      threads: [@props.thread]
      fromView: FocusedMailViewStore.mailView()
    Actions.queueTask(task)

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = { ThreadArchiveQuickAction, ThreadTrashQuickAction }
