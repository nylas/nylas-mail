_ = require 'underscore'
React = require 'react'
{Actions,
 Utils,
 Thread,
 ArchiveThreadHelper,
 CategoryStore,
 ChangeFolderTask,
 ChangeLabelsTask,
 AccountStore} = require 'nylas-exports'

class ThreadListQuickActions extends React.Component
  @displayName: 'ThreadListQuickActions'
  @propTypes:
    thread: React.PropTypes.object
    categoryId: React.PropTypes.string

  render: =>
    actions = []
    if @_shouldDisplayArchiveButton()
      actions.push <div key="archive" className="btn action action-archive" onClick={@_onArchive}></div>
    else if AccountStore.current().usesLabels() and @props.categoryId == CategoryStore.getStandardCategory('all').id
      actions.push <div key="trash" className="btn action action-trash" onClick={@_onTrash}></div>

    return [] if actions.length is 0
    <div className="inner">
      {actions}
    </div>

  shouldComponentUpdate: (newProps, newState) ->
    newProps.thread.id isnt @props?.thread.id

  _shouldDisplayArchiveButton: =>
    if @props.categoryId not in [CategoryStore.getStandardCategory('archive')?.id, CategoryStore.getStandardCategory('trash')?.id, CategoryStore.getStandardCategory('sent')?.id]
      if AccountStore.current().usesLabels()
        if @props.thread.labels.length == 1 and (@props.thread.labels[0].name == "archive" or @props.thread.labels[0].name == "all")
          return false
        return true
      else if @props.thread.folders.length == 1 and @props.thread.folders[0].name == "archive"
        return false
      return true

    return false

  _onTrash: (event) =>
    params =
      thread: @props.thread,
      labelsToRemove: [CategoryStore.byId(@props.categoryId)],
      labelsToAdd: [CategoryStore.getStandardCategory("trash")]
    Actions.queueTask(new ChangeLabelsTask(params))
    # Don't trigger the thread row click
    event.stopPropagation()


  _onForward: (event) =>
    Actions.composeForward({thread: @props.thread, popout: true})
    # Don't trigger the thread row click
    event.stopPropagation()

  _onReply: (event) =>
    Actions.composeReply({thread: @props.thread, popout: true})
    # Don't trigger the thread row click
    event.stopPropagation()

  _onArchive: (event) =>
    archiveTask = ArchiveThreadHelper.getArchiveTask([@props.thread])
    Actions.queueTask(archiveTask)

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = ThreadListQuickActions
