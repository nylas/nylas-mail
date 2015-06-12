_ = require 'underscore'
React = require 'react'
{Actions,
 Utils,
 Thread,
 AddRemoveTagsTask,
 NamespaceStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class ThreadListQuickActions extends React.Component
  @displayName: 'ThreadListQuickActions'
  @propTypes:
    thread: React.PropTypes.object

  render: =>
    actions = []
    actions.push <div className="action" onClick={@_onReply}><RetinaImg name="toolbar-reply.png" mode={RetinaImg.Mode.ContentPreserve} /></div>
    actions.push <div className="action" onClick={@_onForward}><RetinaImg name="toolbar-forward.png" mode={RetinaImg.Mode.ContentPreserve} /></div>
    if not @props.thread.hasTagId('archive')
      actions.push <div className="action" onClick={@_onArchive}><RetinaImg name="toolbar-archive.png" mode={RetinaImg.Mode.ContentPreserve} /></div>

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
    Actions.queueTask(new AddRemoveTagsTask(@props.thread, ['archive'], ['inbox']))

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = ThreadListQuickActions
