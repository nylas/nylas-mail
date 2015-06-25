_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'
{Actions, Utils, FocusedContentStore, WorkspaceStore} = require 'nylas-exports'
{RetinaImg, Popover, Menu} = require 'nylas-component-kit'

ThreadArchiveButton = require './thread-archive-button'
ThreadStarButton = require './thread-star-button'

class MessageToolbarItems extends React.Component
  @displayName: "MessageToolbarItems"

  constructor: (@props) ->
    @state =
      thread: FocusedContentStore.focused('thread')

  render: =>
    classes = classNames
      "message-toolbar-items": true
      "hidden": !@state.thread

    <div className={classes}>
      <ThreadArchiveButton />
      <ThreadStarButton ref="starButton" thread={@state.thread} />
    </div>

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push FocusedContentStore.listen @_onChange

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  _onChange: =>
    @setState
      thread: FocusedContentStore.focused('thread')

module.exports = MessageToolbarItems
