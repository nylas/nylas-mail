_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'

{Actions,
 WorkspaceStore,
 FocusedContentStore} = require 'nylas-exports'

{Menu,
 RetinaImg,
 TimeoutTransitionGroup,
 InjectedComponentSet} = require 'nylas-component-kit'

class MessageToolbarItems extends React.Component
  @displayName: "MessageToolbarItems"

  constructor: (@props) ->
    @state =
      thread: FocusedContentStore.focused('thread')

  render: =>
    <TimeoutTransitionGroup
      className="message-toolbar-items"
      leaveTimeout={125}
      enterTimeout={125}
      transitionName="opacity-125ms">
      {@_renderContents()}
    </TimeoutTransitionGroup>

  _renderContents: =>
    return false unless @state.thread
    <InjectedComponentSet key="injected" matching={role: "message:Toolbar"} exposedProps={thread: @state.thread}/>

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push FocusedContentStore.listen @_onChange

  componentWillUnmount: =>
    return unless @_unsubscribers
    unsubscribe() for unsubscribe in @_unsubscribers

  _onChange: =>
    @setState
      thread: FocusedContentStore.focused('thread')

module.exports = MessageToolbarItems
