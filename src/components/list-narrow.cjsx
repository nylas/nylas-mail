_ = require 'underscore-plus'
React = require 'react'

ThreadListMixin = require './thread-list-mixin'
ThreadListNarrowItem = require './thread-list-narrow-item'

module.exports =
ThreadListNarrow = React.createClass
  displayName: 'ThreadListMixin'
  mixins: [ThreadListMixin]

  render: ->
    <div tabIndex="-1"
         className="thread-list-container thread-list-narrow">
      {@_threadComponents()}
    </div>

  _threadComponents: ->
    @state.threads.map (thread) =>
      <ThreadListNarrowItem key={thread.id}
                            thread={thread}
                            unread={thread.isUnread()}
                            selected={thread?.id == @state?.selected}/>
