_ = require 'underscore'
React = require 'react'
{Actions,
 Utils,
 Thread,
 ArchiveThreadHelper,
 NamespaceStore} = require 'nylas-exports'

class ThreadListQuickActions extends React.Component
  @displayName: 'ThreadListQuickActions'
  @propTypes:
    thread: React.PropTypes.object

  render: =>
    actions = []
    actions.push <div key="reply" className="action action-reply" onClick={@_onReply}></div>
    actions.push <div key="fwd" className="action action-forward" onClick={@_onForward}></div>
    if not @props.thread.hasCategoryName('archive')
      actions.push <div key="archive" className="action action-archive" onClick={@_onArchive}></div>

    <div className="inner">
      {actions}
    </div>

  shouldComponentUpdate: (newProps, newState) ->
    newProps.thread.id isnt @props?.thread.id

  _onForward: (event) =>
    Actions.composeForward({thread: @props.thread, popout: true})
    # Don't trigger the thread row click
    event.stopPropagation()

  _onReply: (event) =>
    Actions.composeReply({thread: @props.thread, popout: true})
    # Don't trigger the thread row click
    event.stopPropagation()

  _onArchive: (event) =>
    task = ArchiveThreadHelper.getArchiveTask([@props.thread])
    Actions.queueTask(task)

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = ThreadListQuickActions
