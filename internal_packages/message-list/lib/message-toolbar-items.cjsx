_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'

{Actions,
 WorkspaceStore,
 FocusedContentStore} = require 'nylas-exports'

{Menu,
 Popover,
 RetinaImg,
 InjectedComponentSet} = require 'nylas-component-kit'

class MessageToolbarItems extends React.Component
  @displayName: "MessageToolbarItems"

  constructor: (@props) ->
    @state =
      thread: FocusedContentStore.focused('thread')

  render: =>
    return false unless @state.thread
    <div className="message-toolbar-items">
      <InjectedComponentSet matching={role: "message:Toolbar"}
                            exposedProps={thread: @state.thread}/>
    </div>

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
