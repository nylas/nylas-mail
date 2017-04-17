_ = require 'underscore'
React = require 'react'
{DraftHelpers,
 Actions,
 Thread,
 ChangeStarredTask,
 ExtensionRegistry,
 AccountStore} = require 'nylas-exports'

class ThreadListIcon extends React.Component
  @displayName: 'ThreadListIcon'
  @propTypes:
    thread: React.PropTypes.object

  _extensionsIconClassNames: =>
    return ExtensionRegistry.ThreadList.extensions()
    .filter((ext) => ext.cssClassNamesForThreadListIcon?)
    .reduce(((prev, ext) => prev + ' ' + ext.cssClassNamesForThreadListIcon(@props.thread)), '')
    .trim()

  _iconClassNames: =>
    if !@props.thread
      return 'thread-icon-star-on-hover'

    extensionIconClassNames = @_extensionsIconClassNames()
    if extensionIconClassNames.length > 0
      return extensionIconClassNames

    if @props.thread.starred
      return 'thread-icon-star'

    if @props.thread.unread
      return 'thread-icon-unread thread-icon-star-on-hover'

    msgs = @_nonDraftMessages()
    last = msgs[msgs.length - 1]

    if msgs.length > 1 and last.from[0]?.isMe()
      if DraftHelpers.isForwardedMessage(last)
        return 'thread-icon-forwarded thread-icon-star-on-hover'
      else
        return 'thread-icon-replied thread-icon-star-on-hover'

    return 'thread-icon-none thread-icon-star-on-hover'

  _nonDraftMessages: =>
    msgs = @props.thread.__messages
    return [] unless msgs and msgs instanceof Array
    msgs = _.filter msgs, (m) -> m.serverId and not m.draft
    return msgs

  shouldComponentUpdate: (nextProps) =>
    return false if nextProps.thread is @props.thread
    true

  render: =>
    <div className="thread-icon #{@_iconClassNames()}"
         title="Star"
         onClick={@_onToggleStar}></div>

  _onToggleStar: (event) =>
    Actions.toggleStarredThreads(threads: [@props.thread], source: "Thread List Icon")
    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = ThreadListIcon
