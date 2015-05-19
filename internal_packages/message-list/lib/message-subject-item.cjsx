_ = require 'underscore'
React = require 'react'
{FocusedContentStore} = require 'nylas-exports'

class MessageSubjectItem extends React.Component
  @displayName: 'MessageSubjectItem'

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @_unsubscriber = FocusedContentStore.listen @_onChange

  componentWillUnmount: =>
    @_unsubscriber() if @_unsubscriber

  render: =>
    <div className="message-toolbar-subject">{@state.thread?.subject}</div>

  _onChange: => _.defer =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    thread: FocusedContentStore.focused('thread')

module.exports = MessageSubjectItem
