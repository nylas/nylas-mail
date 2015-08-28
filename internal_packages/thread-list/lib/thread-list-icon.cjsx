_ = require 'underscore'
React = require 'react'
{Actions,
 Utils,
 Thread,
 ChangeStarredTask,
 AccountStore} = require 'nylas-exports'

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
      return 'thread-icon-unread'

    msgs = @_nonDraftMessages()
    last = msgs[msgs.length - 1]

    if msgs.length > 1 and last.from[0]?.isMe()
      if Utils.isForwardedMessage(last)
        return 'thread-icon-forwarded'
      else
        return 'thread-icon-replied'

    return 'thread-icon-star-on-hover'

  _nonDraftMessages: =>
    msgs = @props.thread.metadata
    return [] unless msgs and msgs instanceof Array
    msgs = _.filter msgs, (m) -> m.serverId and not m.draft
    return msgs

  shouldComponentUpdate: (nextProps) =>
    return false if nextProps.thread is @props.thread
    true

  render: =>
    <div className="thread-icon #{@_iconType()}" onClick={@_onToggleStar}></div>

  _onToggleStar: (event) =>
    task = new ChangeStarredTask(thread: @props.thread, starred: !@props.thread.starred)
    Actions.queueTask(task)

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = ThreadListIcon
