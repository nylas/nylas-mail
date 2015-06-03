_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'
{Actions, Utils, FocusedContentStore, WorkspaceStore} = require 'nylas-exports'
{RetinaImg, Popover, Menu} = require 'nylas-component-kit'

ThreadArchiveButton = require './thread-archive-button'

class MessageToolbarItems extends React.Component
  @displayName: "MessageToolbarItems"

  constructor: (@props) ->
    @state =
      threadIsSelected: FocusedContentStore.focusedId('thread')?

  render: =>
    classes = classNames
      "message-toolbar-items": true
      "hidden": !@state.threadIsSelected

    <div className={classes}>
      <ThreadArchiveButton />
    </div>

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push FocusedContentStore.listen @_onChange

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  _onChange: =>
    @setState
      threadIsSelected: FocusedContentStore.focusedId('thread')?

module.exports = MessageToolbarItems
