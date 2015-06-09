_ = require 'underscore'
React = require 'react'
{Actions,
 Utils,
 Thread,
 AddRemoveTagsTask,
 NamespaceStore} = require 'nylas-exports'

class ThreadListIcon extends React.Component
  @displayName: 'ThreadListIcon'
  @propTypes:
    thread: React.PropTypes.object

  _iconType: =>
    myEmail = NamespaceStore.current()?.emailAddress

    msgs = @props.thread.metadata
    return '' unless msgs and msgs instanceof Array

    msgs = _.filter msgs, (m) -> m.isSaved() and not m.draft
    msg = msgs[msgs.length - 1]
    return '' unless msgs.length > 0

    if @props.thread.hasTagId('starred')
      return 'thread-icon-star'
    else if @props.thread.unread
      return 'thread-icon-unread thread-icon-star-on-hover'
    else if msg.from[0]?.email isnt myEmail or msgs.length is 1
      return 'thread-icon-star-on-hover'
    else if Utils.isForwardedMessage(msg)
      return 'thread-icon-forwarded thread-icon-star-on-hover'
    else
      return 'thread-icon-replied thread-icon-star-on-hover'

  render: =>
    <div className="thread-icon #{@_iconType()}" onClick={@_onToggleStar}></div>

  _onToggleStar: (event) =>
    if @props.thread.hasTagId('starred')
      star = new AddRemoveTagsTask(@props.thread, [], ['starred'])
    else
      star = new AddRemoveTagsTask(@props.thread, ['starred'], [])
    Actions.queueTask(star)

    # Don't trigger the thread row click
    event.stopPropagation()

module.exports = ThreadListIcon
