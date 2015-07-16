_ = require 'underscore'
React = require 'react'
{Actions,
 Utils,
 Thread,
 UpdateThreadsTask,
 NamespaceStore} = require 'nylas-exports'

class ThreadListIcon extends React.Component
  @displayName: 'ThreadListIcon'
  @propTypes:
    thread: React.PropTypes.object

  _iconType: =>
    if !@props.thread
      return 'thread-icon-star-on-hover'

    if @props.thread.starred
      return 'thread-icon-star'

    if @props.thread.unread
      return 'thread-icon-unread thread-icon-star-on-hover'

    msgs = @_nonDraftMessages()
    last = msgs[msgs.length - 1]

    myEmail = NamespaceStore.current()?.emailAddress
    if msgs.length > 1 and last.from[0]?.email is myEmail
      if Utils.isForwardedMessage(last)
        return 'thread-icon-forwarded thread-icon-star-on-hover'
      else
        return 'thread-icon-replied thread-icon-star-on-hover'

    return 'thread-icon-star-on-hover'

  _nonDraftMessages: =>
    msgs = @props.thread.metadata
    return [] unless msgs and msgs instanceof Array
    msgs = _.filter msgs, (m) -> m.isSaved() and not m.draft
    return msgs

  render: =>
    <div className="thread-icon #{@_iconType()}" onClick={@_onToggleStar}></div>

  _onToggleStar: (event) =>
    values = starred: (not @props.thread.starred)
    task = new UpdateThreadsTask([@props.thread], values)
    Actions.queueTask(task)

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = ThreadListIcon
